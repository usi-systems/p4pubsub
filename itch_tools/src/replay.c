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
#include <time.h>
#include <sys/time.h>

#include "libtrading/proto/nasdaq_itch50_message.h"
#include "libtrading/proto/omx_moldudp_message.h"
#include "../third-party/libtrading/lib/proto/nasdaq_itch50_message.c"

#include "common.c"

char *progname;

void error(char *msg) {
    perror(msg);
    exit(-1);
}


#define BUFSIZE 2048
char buf[BUFSIZE];

void usage(int rc) {
    printf("Usage: %s [-a OPTIONS] [-t MSG_TYPES] [-r MSGS_PER_S] [-m MAX_MESSAGES] [-h HOST -p PORT] [-o OUT_FILENAME] FILENAME\n\
\n\
OPTIONS is a string of chars, which can include:\n\
    t - print stats on number of messages by type\n\
    a - print Add Order messages as TSV\n\
    s - print the symbol of each Add Order message\n\
\n\
", progname);
    exit(rc);
}

struct session_stats {
    unsigned msg_types[26];
    unsigned total;
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

    printf("\nTotal number of messages: %d\n", stats->total);
    printf("\nNumber of messages by MessageType:\n");
    for (i = 0; i < 26; i++) {
        unsigned char t = letters[i];
        if (stats->msg_types[t-65] > 0)
            printf("%c: %d\n", t, stats->msg_types[t-65]);
    }
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

#define MIN_SLEEP_NS 70000

struct rate_limit_state {
    struct timespec interval;
    struct timespec last_call;
    long outstanding_ns;
};

// XXX this does not work (it sleeps for too long)
void rate_limiter(struct rate_limit_state *state) {
    if (state->interval.tv_sec == 0 && state->interval.tv_nsec == 0) return;
    struct timespec now;
    struct timespec elapsed;
    struct timespec wait;
    if (state->last_call.tv_sec > 0) {
        clock_gettime(CLOCK_REALTIME, &now);
        timespec_diff(&state->last_call, &now, &elapsed);
        timespec_diff(&elapsed, &state->interval, &wait);

        if (wait.tv_sec > 0 || (wait.tv_sec >= 0 && wait.tv_nsec + state->outstanding_ns > MIN_SLEEP_NS)) {
            wait.tv_nsec += state->outstanding_ns;
            nanosleep(&wait, NULL);
            state->outstanding_ns = 0;
        }
        else {
            state->outstanding_ns += wait.tv_nsec;
        }
    }
    else { // initialize state
        state->outstanding_ns = 0;
    }
    clock_gettime(CLOCK_REALTIME, &state->last_call);
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
    int do_print_symbols = 0;
    int do_print_ao = 0;
    struct session_stats stats;
    float msgs_per_s = 0;
    bzero(&stats, sizeof(struct session_stats));
    struct rate_limit_state rate_state;
    bzero(&rate_state, sizeof(rate_state));
    unsigned long long timestamp;
    char *extra_options = 0;

    progname = basename(argv[0]);

    while ((opt = getopt(argc, argv, "a:m:t:o:h:p:r:")) != -1) {
        switch (opt) {
            case 'm':
                max_messages = atoi(optarg);
                break;
            case 'a':
                extra_options = optarg;
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
            case 'r':
                msgs_per_s = atof(optarg);
                break;
            default: /* '?' */
                usage(-1);
        }
    }

    if (hostname && !port)
        usage(-1);

    if (argc - optind != 1)
        usage(-1);

    if (extra_options) {
        if (strchr(extra_options, 't'))
            do_stats = 1;
        if (strchr(extra_options, 's'))
            do_print_symbols = 1;
        if (strchr(extra_options, 'a'))
            do_print_ao = 1;
    }

    char *filename = argv[optind];

    long double min_interval_secs =msgs_per_s > 0 ? 1 / msgs_per_s : 0;
    secs2ts(min_interval_secs, &rate_state.interval);
    //printf("min_interval: %lds %ldns\n", rate_state.interval.tv_sec, rate_state.interval.tv_nsec);

    fd = open(filename, O_RDONLY);
    if (fd < 0)
        error("open()");

    int fd_out = -1;
    if (out_filename) {
        fd_out = open(out_filename, O_WRONLY | O_CREAT | O_TRUNC, 0664);
        if (fd_out < 0)
            error("open() out_filename");
    }

    fprintf(stderr, "Replaying: %s\n", filename);

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

    if (do_print_ao)
        print_add_order_header();

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

        if (m->MessageType == ITCH50_MSG_ADD_ORDER) {
            struct itch50_msg_add_order *ao = (struct itch50_msg_add_order *)(payload);
            if (do_print_symbols)
                printf("%.*s\n", 8, ao->Stock);
            if (do_print_ao) {
                print_add_order(ao);
            }

        }

        if (!skip) {
            if (do_stats) {
                stats.msg_types[m->MessageType - 65]++;
                stats.total += 1;
            }

            rate_limiter(&rate_state);

            if (sockfd > -1) {

                struct omx_moldudp_header *h = (struct omx_moldudp_header *)buf;
                struct omx_moldudp_message *mm = (struct omx_moldudp_message *) (buf + sizeof(struct omx_moldudp_header));
                h->Session[7] = 0;
                h->SequenceNumber = seq;
                h->MessageCount = 1;
                mm->MessageLength = len;
                memcpy(buf + sizeof(struct omx_moldudp_header) + sizeof(struct omx_moldudp_message), payload, len);
                if (m->MessageType == ITCH50_MSG_ADD_ORDER) {
                    struct itch50_msg_add_order *ao = (struct itch50_msg_add_order *)(buf + sizeof(struct omx_moldudp_header) + sizeof(struct omx_moldudp_message));
                    timestamp = us_since_midnight();
                    memcpy(ao->Timestamp, &timestamp, 6);
                }


                size_t pkt_size = sizeof(struct omx_moldudp_header) + sizeof(struct omx_moldudp_message) + len;
                if (sendto(sockfd, buf, pkt_size, 0,
                            (struct sockaddr *)&remoteaddr, sizeof(remoteaddr)) < 0)
                    error("sendto()");
            }

            if (fd_out > -1) {
                n = write(fd_out, data+pos, 2+len);
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
