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

#include "common.c"

char *progname;
int verbosity = 0;

void error(char *msg) {
    perror(msg);
    exit(-1);
}


#define BUFSIZE 2048
char buf[BUFSIZE];

void usage(int rc) {
    fprintf(rc == 0 ? stdout : stderr,
    "Usage: %s [-a OPTIONS] [-v VERBOSITY] [-R MSG/S] [-r FILENAME]  HOST[:PORT]\n\
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
    int n, msg_num, msg_len, pkt_offset, pkt_size;
    short msg_count;
    struct stat s;
    struct sockaddr_in remoteaddr;
    char *filename = 0;
    float msgs_per_s = 0;
    struct rate_limit_state rate_state;
    bzero(&rate_state, sizeof(rate_state));
    uint64_t timestamp;
    char *extra_options = 0;
    int do_print_ao = 0;
    struct omx_moldudp64_header *h;
    struct omx_moldudp64_message *mm;
    struct itch50_message *m;
    struct itch50_msg_add_order *ao;
    int pkt_cnt = 0;

    progname = basename(argv[0]);

    while ((opt = getopt(argc, argv, "ha:m:v:r:R:")) != -1) {
        switch (opt) {
            case 'a':
                extra_options = optarg;
                break;
            case 'r':
                filename = optarg;
                break;
            case 'R':
                msgs_per_s = atof(optarg);
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

    long double min_interval_secs =msgs_per_s > 0 ? 1 / msgs_per_s : 0;
    secs2ts(min_interval_secs, &rate_state.interval);
    //printf("min_interval: %lds %ldns\n", rate_state.interval.tv_sec, rate_state.interval.tv_nsec);

    FILE *fh = stdin;
    if (filename) {
        if (strcmp(filename, "-") != 0) {
            fh = fopen(filename, "rb");
            if (!fh)
                error("fopen()");
        }
    }


    if (verbosity > 0)
        fprintf(stderr, "Replaying from %s\n", filename ? filename : "STDIN");

    int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
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

    while (1) {
        pkt_offset = sizeof(struct omx_moldudp64_header);

        if (!fread(buf, pkt_offset, 1, fh)) {
            if (feof(fh))
                break;
            else
                error("fread()");
        }

        h = (struct omx_moldudp64_header *)buf;
        msg_count = ntohs(h->MessageCount);

        for (msg_num = 0; msg_num < msg_count; msg_num++) {
            if (!fread(buf+pkt_offset, 2, 1, fh))
                error("fread()");

            mm = (struct omx_moldudp64_message *) (buf + pkt_offset);
            msg_len = ntohs(mm->MessageLength);

            if (!fread(buf+pkt_offset+2, msg_len, 1, fh))
                error("fread()");

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

        if (verbosity > 1)
            printf("Sent %d bytes\n", pkt_offset);

        pkt_cnt++;
    }

    if (verbosity > 0)
        fprintf(stderr, "Sent %d packets\n", pkt_cnt);


    close(sockfd);
    fclose(fh);

    return 0;
}
