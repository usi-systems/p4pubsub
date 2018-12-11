#include "common.c"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <libgen.h>
#include <time.h>

#include "libtrading/proto/nasdaq_itch50_message.h"
#include "libtrading/proto/omx_moldudp_message.h"
#include "../third-party/libtrading/lib/proto/nasdaq_itch50_message.c"

char *progname;
int verbosity = 0;


void usage(int rc) {
    fprintf(rc == 0 ? stdout : stderr,
    "Usage: %s [-a OPTIONS] [-p CPU] [-v VERBOSITY] -r FILENAME HOST[:PORT]\n\
\n\
    -p CPU     Pin process to CPU.\n\
\n\
OPTIONS is a string of chars, which can include:\n\
    a - print Add Order messages as TSV\n\
\n\
", progname);
    exit(rc);
}


void timespec_diff(struct timespec *start, struct timespec *stop,
                   struct timespec *result) {
    if ((stop->tv_nsec - start->tv_nsec) < 0) {
        result->tv_sec = stop->tv_sec - start->tv_sec - 1;
        result->tv_nsec = stop->tv_nsec - start->tv_nsec + 1000000000;
    } else {
        result->tv_sec = stop->tv_sec - start->tv_sec;
        result->tv_nsec = stop->tv_nsec - start->tv_nsec;
    }
}

static void secs2ts(long double secs, struct timespec *ts) {
    ts->tv_sec = secs;
    ts->tv_nsec = (secs - ts->tv_sec) * 1.0e9;
}

int main(int argc, char *argv[]) {
    int opt;
    int n, msg_num, msg_len, pkt_offset, pkt_size;
    short msg_count;
    struct stat s;
    struct sockaddr_in remoteaddr;
    char *filename = 0;
    uint64_t timestamp;
    char *extra_options = 0;
    int do_print_ao = 0;
    int sendbuf = 0;
    struct omx_moldudp64_header *h;
    struct omx_moldudp64_message *mm;
    struct itch50_message *m;
    struct itch50_msg_add_order *ao;
    int pkt_cnt = 0;
    int pin_cpu = -1;

    progname = basename(argv[0]);

    while ((opt = getopt(argc, argv, "ha:m:b:v:r:p:")) != -1) {
        switch (opt) {
            case 'a':
                extra_options = optarg;
                break;
            case 'b':
                sendbuf = atoi(optarg);
                break;
            case 'p':
                pin_cpu = atoi(optarg);
                break;
            case 'r':
                filename = optarg;
                break;
            case 'v':
                verbosity = atoi(optarg);
                break;
            case 'h':
                usage(0);
                break;
            default: /* '?' */
                usage(-1);
        }
    }

    if (argc - optind != 1)
        usage(-1);

    char *send_host_port = argv[optind];

    if (extra_options) {
        if (strchr(extra_options, 'a'))
            do_print_ao = 1;
    }

    char hostname[256];
    int port;
    short host_ok, port_ok;
    parse_host_port(send_host_port, 0, hostname, &host_ok, &port, &port_ok);
    if (!host_ok) {
        fprintf(stderr, "Failed to parse hostname: '%s'\n", send_host_port);
        usage(-1);
    }
    if (!port_ok)
        port = 1234;

    if (!filename) {
        fprintf(stderr, "Must specify a file\n");
        usage(-1);
    }

    if (pin_cpu > -1) {
        pin_thread(pin_cpu);
        if (verbosity > 0)
            fprintf(stderr, "Pinned process to CPU %d\n", pin_cpu);
    }


    FILE *fh = fopen(filename, "rb");
    if (!fh)
        error("fopen()");
    fseek(fh, 0, SEEK_END);
    size_t file_size = ftell(fh);
    fseek(fh, 0, SEEK_SET);

    char *data = (char *)malloc(file_size);
    if (!fread(data, file_size, 1, fh))
        error("fread()");

    if (verbosity > 0)
        fprintf(stderr, "Replaying from %s\n", filename ? filename : "STDIN");

    int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sockfd < 0)
        error("socket()");

    if (sendbuf > 0) {
        if (setsockopt(sockfd, SOL_SOCKET, SO_SNDBUF, &sendbuf, sizeof(sendbuf)) < 0)
            error("setsockopt()");
        if (verbosity > 0)
            printf("Socket kernel send buffer set to %d bytes\n", sendbuf);
    }

    int disable = 1;
    if (setsockopt(sockfd, SOL_SOCKET, SO_NO_CHECK, &disable, sizeof(disable)) < 0)
        error("setsockopt()");

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

    char *buf = data;
    while (buf < (data+file_size)) {
        pkt_offset = sizeof(struct omx_moldudp64_header);

        h = (struct omx_moldudp64_header *)buf;
        msg_count = ntohs(h->MessageCount);

        for (msg_num = 0; msg_num < msg_count; msg_num++) {
            mm = (struct omx_moldudp64_message *) (buf + pkt_offset);
            msg_len = ntohs(mm->MessageLength);

            m = (struct itch50_message *)(buf + pkt_offset + 2);
            int expected_size = itch50_message_size(m->MessageType);
            if (expected_size != msg_len)
                fprintf(stderr, "MessageType %c should have size %d, found %d\n", m->MessageType, expected_size, msg_len);

            if (m->MessageType == ITCH50_MSG_ADD_ORDER) {
                ao = (struct itch50_msg_add_order *)m;
                if (do_print_ao)
                    print_add_order(ao);
                timestamp = htonll(ns_since_midnight());
                memcpy(ao->Timestamp, (void*)&timestamp + 2, 6);
            }

            pkt_offset += msg_len + 2;
        }

        if (sendto(sockfd, buf, pkt_offset, 0,
                    (struct sockaddr *)&remoteaddr, sizeof(remoteaddr)) < 0)
            error("sendto()");

        if (verbosity > 2)
            printf("Sent %d bytes\n", pkt_offset);

        buf += pkt_offset;

        pkt_cnt++;
    }

    if (verbosity > 0)
        fprintf(stderr, "Sent %d packets\n", pkt_cnt);


    close(sockfd);
    fclose(fh);

    return 0;
}
