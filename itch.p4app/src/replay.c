#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <libgen.h>


#include "libtrading/proto/nasdaq_itch50_message.h"
#include "libtrading/proto/nasdaq_itch41_message.h"
#include "libtrading/proto/omx_moldudp_message.h"
#include "../third-party/libtrading/lib/proto/nasdaq_itch50_message.c"

char *progname;

void error(char *msg) {
    perror(msg);
    exit(-1);
}


#define BUFSIZE 2048
char buf[BUFSIZE];

void usage(int rc) {
    printf("Usage: %s [-s] [-m MAX_MESSAGES] [-h HOST -p PORT] [-o OUT_FILENAME] FILENAME\n", progname);
    exit(rc);
}

struct session_stats {
    unsigned msg_types[26];
};

void print_stats(struct session_stats *stats) {
    int i;
    unsigned char letters[26];
    for (i = 0; i < 26; i++)
        letters[i] = 65+i;

    int compare_msg_cnt(const void *a, const void *b) {
        return stats->msg_types[*((unsigned char *)b)-65] - stats->msg_types[*((unsigned char *)a)-65];
    }
    qsort(letters, 26, sizeof(unsigned char), compare_msg_cnt);

    printf("\nNumber of messages by MessageType:\n");
    for (i = 0; i < 26; i++) {
        unsigned char t = letters[i];
        if (stats->msg_types[t-65] > 0)
            printf("%c: %d\n", t, stats->msg_types[t-65]);
    }
}

int main(int argc, char *argv[]) {
    int opt;
    int fd, n;
    struct stat s;
    int status;
    size_t size;
    const char *data;
    struct sockaddr_in remoteaddr;
    unsigned max_messages = 0;
    char *filter_types = 0;
    char *out_filename = 0;
    char *hostname = 0;
    int port = 0;
    int do_stats = 0;
    struct session_stats stats;
    bzero(&stats, sizeof(struct session_stats));

    progname = basename(argv[0]);

    while ((opt = getopt(argc, argv, "sm:t:o:h:p:")) != -1) {
        switch (opt) {
            case 'm':
                max_messages = atoi(optarg);
                break;
            case 'o':
                out_filename = optarg;
                break;
            case 't':
                filter_types = optarg;
                break;
            case 'p':
                port = atoi(optarg);
                break;
            case 'h':
                hostname = optarg;
                break;
            case 's':
                do_stats = 1;
                break;
            default: /* '?' */
                usage(-1);
        }
    }

    if (hostname && !port)
        usage(-1);

    if (argc - optind != 1)
        usage(-1);

    char *filename = argv[optind];

    fd = open(filename, O_RDONLY);
    if (fd < 0)
        error("open()");

    int fd_out = -1;
    if (out_filename) {
        fd_out = open(out_filename, O_WRONLY | O_CREAT | O_TRUNC, 0664);
        if (fd_out < 0)
            error("open() out_filename");
    }

    printf("Replaying: %s\n", filename);

    status = fstat(fd, &s);
    if (status < 0) error("fstat()");
    size = s.st_size;

    data = mmap(NULL, size, PROT_READ, MAP_PRIVATE, fd, 0);
    if (data == MAP_FAILED) error("mmap()");

    int sockfd = -1;
    if (hostname) {
        sockfd = socket(AF_INET, SOCK_DGRAM, 0);
        if (sockfd < 0)
            error("socket()");

        if (strcmp(hostname, "255.255.255.255") == 0) {
            int enable_bcast = 1;
            if (setsockopt(sockfd, SOL_SOCKET, SO_BROADCAST, &enable_bcast, sizeof(int)) < 0)
                error("setsockopt() SO_BROADCAST");
        }


        struct hostent *server = gethostbyname(hostname);
        if (server == NULL) {
            fprintf(stderr, "bad hostname: %s\n", hostname);
            exit(0);
        }

        bzero((char *) &remoteaddr, sizeof(remoteaddr));
        remoteaddr.sin_family = AF_INET;
        bcopy((char *)server->h_addr,
                (char *)&remoteaddr.sin_addr.s_addr, server->h_length);
        remoteaddr.sin_port = htons(port);
    }


    int skip = 0;
    int pos = 0;
    int seq = 0;
    while (pos < size) {
        const short len = ntohs(*(const short *)(data + pos));
        const char *payload = data + pos + 2;

        struct itch50_message *m = (struct itch50_message *)(payload);
        int expected_size = itch50_message_size(m->MessageType);
        if (expected_size != len)
            fprintf(stderr, "MessageType %c should have size %d, found %d\n", m->MessageType, expected_size, len);

        skip = 0;
        if (filter_types) {
            if (!strchr(filter_types, m->MessageType))
                skip = 1;
        }

        if (!skip) {
            if (do_stats) {
                stats.msg_types[m->MessageType - 65]++;
            }

            if (sockfd > -1) {

                struct omx_moldudp_header *h = (struct omx_moldudp_header *)buf;
                struct omx_moldudp_message *mm = (struct omx_moldudp_message *) (buf + sizeof(struct omx_moldudp_header));
                h->Session[7] = 0;
                h->SequenceNumber = seq;
                h->MessageCount = 1;
                mm->MessageLength = len;
                memcpy(buf + sizeof(struct omx_moldudp_header) + sizeof(struct omx_moldudp_message), payload, len);

                size_t pkt_size = sizeof(struct omx_moldudp_header) + sizeof(struct omx_moldudp_message) + len;
                if (sendto(sockfd, buf, pkt_size, 0,
                            (struct sockaddr *)&remoteaddr, sizeof(remoteaddr)) < 0)
                    error("sendto()");
            }

            if (fd_out > -1) {
                write(fd_out, data+pos, 2+len);
            }

            seq += 1;
        }

        pos += len + 2;
        if (max_messages > 0 && seq == max_messages)
            break;
    }

    if (do_stats)
        print_stats(&stats);

    if (sockfd > -1)
        close(sockfd);

    if (fd_out > -1)
        close(fd_out);

    return 0;
}
