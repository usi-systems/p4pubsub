#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <sched.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <string.h>
#include <libgen.h>
#include <signal.h>
#include <fcntl.h>
#include <assert.h>
#include <math.h>
#include <pthread.h>

#include "libtrading/proto/nasdaq_itch50_message.h"
#include "libtrading/proto/omx_moldudp_message.h"
#include "../third-party/libtrading/lib/proto/nasdaq_itch50_message.c"

#include "pipe.h"
#include "common.c"

#define BUFSIZE 2048

char listen_hostname[256];

char *progname;

int verbosity = 0;

int sockfd = 0;
FILE *fh_log = 0;
int pkt_cnt = 0;
int matching_cnt = 0;
pthread_t consumer_thread;
pipe_consumer_t* message_queue_r;
pipe_producer_t* message_queue_w;

void usage(int rc) {
    fprintf(rc == 0 ? stdout : stderr,
            "Usage: %s [-v VERBOSITY] [-o OPTIONS] [-T US] [-b SO_RCVBUF] [-q Q_SIZE] [-m MAX_PKTS] [-t LOG_FILENAME] [-f FWD_HOST:PORT] [-s STOCKS] [[LISTEN_HOST:]PORT]\n\
\n\
OPTIONS is a string of chars, which can include:\n\
\n\
    a - print Add Order messages as TSV\n\
    o - print other message types\n\
    u - update timestamp when forwarding message\n\
    i - ignore filter\n\
    A - assert that all messages match the filter\n\
\n\
", progname);
    exit(rc);
}


size_t ring_buf_count;
size_t ring_buf_el_size;
void *ring_buf;
int ring_buf_idx;

void ring_buf_init(size_t el_size, size_t el_count) {
    ring_buf_el_size = el_size;
    ring_buf_count = el_count;
    ring_buf = malloc(el_count * el_size);
    ring_buf_idx = 0;
}

void *ring_buf_next() {
    ring_buf_idx = (ring_buf_idx + 1) % ring_buf_count;
    return ring_buf + (ring_buf_idx * ring_buf_el_size);
}


void cleanup_and_exit() {
    if (fh_log)
        fclose(fh_log);

    if (sockfd)
        close(sockfd);

    void *stop_processing = NULL;
    pipe_push(message_queue_w, &stop_processing, 1);

    if (pthread_join(consumer_thread, NULL)) {
        error("pthread_join()");
    }


    fprintf(stderr, "\nReceived %d packets (%d matched filter)\n", pkt_cnt, matching_cnt);
    exit(0);
}

void catch_int(int signo) {
    cleanup_and_exit();
}

void busy_work(unsigned us) {
    unsigned i;
    long double x = 3.14159265359;
    struct timespec ts1, ts2;
    long long unsigned elapsed_us = 0;

    if (clock_gettime(CLOCK_MONOTONIC, &ts1) != 0)
        error("clock_gettime()");

    while (elapsed_us < us) {

        for (i = 0; i < 10; i++)
            x = sqrt(x*x) * sqrt(x*x);

        if (clock_gettime(CLOCK_MONOTONIC, &ts2) != 0)
            error("clock_gettime()");

        elapsed_us = (ts2.tv_sec*1000000 + ts2.tv_nsec/1000) -
                     (ts1.tv_sec*1000000 + ts1.tv_nsec/1000);
    }
}

int count_chars(char *s, char c) {
    int i, count;
    for (i=0, count=0; s[i]; i++) count += (s[i] == c);
    return count;
}


struct {
    int count;
    char **stocks;
} filtered_stocks;

void parse_stocks_str(char *stocks_with_commas) {
    int i, stock_len;

    filtered_stocks.count = count_chars(stocks_with_commas, ',') + 1;

    int ptrs_size = sizeof(char*) * filtered_stocks.count;
    int strs_size = (STOCK_SIZE * filtered_stocks.count);

    filtered_stocks.stocks = (char **) malloc(ptrs_size + strs_size);
    char *strs = (char*)filtered_stocks.stocks + ptrs_size;
    memset(strs, ' ', strs_size);

    char *s = stocks_with_commas;
    char *comma;
    for (i = 0; i < filtered_stocks.count; i++) {
        filtered_stocks.stocks[i] = strs + (i * STOCK_SIZE);

        comma = strchr(s, ',');
        stock_len = comma ? comma - s : strlen(s);
        assert(stock_len <= 8);
        memcpy(filtered_stocks.stocks[i], s, stock_len);

        s = comma+1;
    }
}

int matches_filter(struct itch50_msg_add_order *ao) {
    if (filtered_stocks.count == 0) return 1;
    for (int i = 0; i < filtered_stocks.count; i++)
        if (memcmp(filtered_stocks.stocks[i], ao->Stock, STOCK_SIZE) == 0)
            return 1;
    return 0;
}

void print_filtered_stocks() {
    int i;
    printf(filtered_stocks.count ? "Filtering for stocks:\n" : "Not filtering for stocks\n");
    for (i = 0; i < filtered_stocks.count; i++) {
        printf("\t%.*s\n", 8, filtered_stocks.stocks[i]);
    }
}

int do_print_ao = 0;
unsigned busy_work_us = 0;
int do_update_timestamp = 0;
char *forward_host_port = 0;
struct sockaddr_in forward_addr;

void pin_thread(int cpu) {
    cpu_set_t mask;
    CPU_ZERO(&mask);
    CPU_SET(cpu, &mask);
    if (sched_setaffinity(0, sizeof(cpu_set_t), &mask) < 0)
        error("sched_setaffinity()");
}

void assert_thread_affinity(int cpu) {
    cpu_set_t mask;
    if (sched_getaffinity(0, sizeof(cpu_set_t), &mask) < 0)
        error("sched_getaffinity()");
    assert(CPU_ISSET(cpu, &mask));
}

void *process_messages(void *ignored) {
    struct itch50_msg_add_order *ao;
    size_t pop_cnt;
    unsigned long long timestamp;
    char send_buf[BUFSIZE];
    struct omx_moldudp64_header *h;
    struct omx_moldudp64_message *mm;
    h = (struct omx_moldudp64_header *)send_buf;
    mm = (struct omx_moldudp64_message *) (send_buf + sizeof(struct omx_moldudp64_header));
    mm->MessageLength = htons(sizeof(struct itch50_msg_add_order));
    h->MessageCount = htons(1);
    size_t size = sizeof(struct omx_moldudp64_header) +
                  sizeof(struct omx_moldudp64_message) +
                  sizeof(struct itch50_msg_add_order);

    pin_thread(1);
    assert_thread_affinity(1);

    while (1) {
        pop_cnt = pipe_pop(message_queue_r, &ao, 1);
        if (ao == NULL)
            break;

        if (do_print_ao)
            print_add_order(ao);

        if (fh_log) {
            timestamp = ns_since_midnight();
            fwrite(ao->Timestamp, 6, 1, fh_log);
            fwrite(&timestamp, 6, 1, fh_log);
            fwrite(ao->Stock, 8, 1, fh_log);
        }

        if (busy_work_us)
            busy_work(busy_work_us);

        if (do_update_timestamp) {
            timestamp = htonll(ns_since_midnight());
            memcpy(ao->Timestamp, (void*)&timestamp + 2, 6);
        }

        if (forward_host_port) {
            memcpy((void*)mm + 2, ao, sizeof(struct itch50_msg_add_order));

            if (sendto(sockfd, send_buf, size, 0,
                        (struct sockaddr *)&forward_addr, sizeof(forward_addr)) < 0)
                error("sendto()");
        }
    }
}

int main(int argc, char *argv[]) {
    int opt;
    char *stocks_with_commas = 0;
    char *listen_host_port = 0;
    char forward_hostname[256];
    int forward_port;
    strcpy(listen_hostname, "127.0.0.1");
    int port;
    short host_ok, port_ok;
    char *log_filename = 0;
    char *extra_options = 0;
    int do_print_msgs = 0;
    int do_ignore_filter = 0;
    int do_assert_match_filter = 0;
    int rcvbuf = 0;
    int msg_num;
    short msg_count;
    int msg_len;
    int pkt_offset;
    int max_packets = 0;
    int queue_size = 64;
    struct omx_moldudp64_header *h;
    struct omx_moldudp64_message *mm;
    struct itch50_message *m;
    struct itch50_msg_add_order *ao;

    filtered_stocks.count = 0;

    progname = basename(argv[0]);

    while ((opt = getopt(argc, argv, "hv:o:b:q:t:f:s:m:T:")) != -1) {
        switch (opt) {
            case 'o':
                extra_options = optarg;
                break;
            case 'f':
                forward_host_port = optarg;
                break;
            case 'v':
                verbosity = atoi(optarg);
                break;
            case 'b':
                rcvbuf = atoi(optarg);
                break;
            case 'q':
                queue_size = atoi(optarg);
                break;
            case 't':
                log_filename = optarg;
                break;
            case 'T':
                busy_work_us = atoi(optarg);
                break;
            case 's':
                stocks_with_commas = optarg;
                break;
            case 'l':
                listen_host_port = optarg;
                break;
            case 'm':
                max_packets = atoi(optarg);
                break;
            case 'h':
                usage(0);
            default: /* '?' */
                usage(-1);
        }
    }

    if (argc - optind > 1)
        usage(-1);
    else if (argc - optind == 1)
        listen_host_port = argv[optind];

    if (listen_host_port) {
        int parsed_port;
        parse_host_port(listen_host_port, 1, listen_hostname, &host_ok, &port, &port_ok);
        if (!port_ok)
            port = 1234;
    }

    if (!is_pow2(queue_size)) {
        fprintf(stderr, "Queue size must be a power of 2\n");
        exit(-1);
    }

    if (extra_options) {
        if (strchr(extra_options, 'a'))
            do_print_ao = 1;
        if (strchr(extra_options, 'o'))
            do_print_msgs = 1;
        if (strchr(extra_options, 'u'))
            do_update_timestamp = 1;
        if (strchr(extra_options, 'i'))
            do_ignore_filter = 1;
        if (strchr(extra_options, 'A'))
            do_assert_match_filter = 1;
    }

    if (log_filename) {
        fh_log = fopen(log_filename, "wb");
        if (!fh_log)
            error("open() log_filename");
    }


    if (forward_host_port) {
        parse_host_port(forward_host_port, 0, forward_hostname, &host_ok, &forward_port, &port_ok);
        if (!host_ok)
            strcpy(forward_hostname, "127.0.0.1");
        if (!port_ok)
            forward_port = 1234;

        struct hostent *server = gethostbyname(forward_hostname);
        if (server == NULL) {
            fprintf(stderr, "bad forward hostname: %s\n", forward_hostname);
            exit(-1);
        }

        bzero((char *) &forward_addr, sizeof(forward_addr));
        forward_addr.sin_family = AF_INET;
        bcopy((char *)server->h_addr,
                (char *)&forward_addr.sin_addr.s_addr, server->h_length);
        forward_addr.sin_port = htons(forward_port);

        if (verbosity > 0)
            fprintf(stderr, "Forwarding to %s:%d\n", forward_hostname, forward_port);
    }



    signal(SIGINT, catch_int);



    int i, size;
    struct sockaddr_in localaddr;
    struct sockaddr_in remoteaddr;

    if (stocks_with_commas)
        parse_stocks_str(stocks_with_commas);

    if (verbosity > 0)
        print_filtered_stocks();

    if (verbosity > 0 && do_ignore_filter)
        printf("Filters will be computed on each packet, but the result will be ignored.\n");

    if (verbosity > 0 && busy_work_us)
        printf("Doing %uus of busy work for each matching message received.\n", busy_work_us);

    if (verbosity > 0)
        printf("Queue size set to %d elements\n", queue_size);


    sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sockfd < 0)
        error("socket()");

    int optval = 1;
    setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR,
            (const void *)&optval , sizeof(int));

    bzero((char *)&localaddr, sizeof(localaddr));
    localaddr.sin_family = AF_INET;
    localaddr.sin_addr.s_addr = htonl(INADDR_ANY);
    localaddr.sin_port = htons(port);

    if (bind(sockfd, (struct sockaddr *)&localaddr, sizeof(localaddr)) < 0)
        error("bind()");

    if (verbosity > 0)
        fprintf(stderr, "Listenning on port %d\n", port);

    if (rcvbuf > 0) {
        if (setsockopt(sockfd, SOL_SOCKET, SO_RCVBUF, &rcvbuf, sizeof(rcvbuf)) < 0)
            error("setsockopt()");
        if (verbosity > 0)
            printf("Socket kernel receive buffer set to %d bytes\n", rcvbuf);
    }

    int remoteaddr_len = sizeof(remoteaddr);

    int matched_filter;

    pipe_t* pipe = pipe_new(sizeof(struct itch50_message *), queue_size-1);
    //pipe_reserve(PIPE_GENERIC(pipe), queue_size-1);
    message_queue_w = pipe_producer_new(pipe);
    message_queue_r = pipe_consumer_new(pipe);
    pipe_free(pipe);

    ring_buf_init(BUFSIZE, queue_size+1);
    char *buf = ring_buf_next();

    if (pthread_create(&consumer_thread, NULL, process_messages, NULL)) {
        error("pthread_create()");
    }

    pin_thread(0);
    assert_thread_affinity(0);

    while (1) {
        matched_filter = 0;

        size = recvfrom(sockfd, buf, ring_buf_el_size, 0,
                (struct sockaddr *)&remoteaddr, &remoteaddr_len);
        if (size < 0)
            error("recvfrom()");

        pkt_cnt++;

        h = (struct omx_moldudp64_header *)buf;
        pkt_offset = sizeof(struct omx_moldudp64_header);

        msg_count = ntohs(h->MessageCount);

        for (msg_num = 0; msg_num < msg_count; msg_num++) {
            mm = (struct omx_moldudp64_message *) (buf + pkt_offset);
            msg_len = ntohs(mm->MessageLength);
            m = (struct itch50_message *) (buf + pkt_offset + 2);

            int expected_size = itch50_message_size(m->MessageType);
            if (expected_size != msg_len)
                fprintf(stderr, "MessageType %c should have size %d, found %d\n", m->MessageType, expected_size, msg_len);

            if (m->MessageType == ITCH50_MSG_ADD_ORDER) {
                ao = (struct itch50_msg_add_order *)m;
                if (matches_filter(ao) || do_ignore_filter) {
                    matched_filter = 1;
                    pipe_push(message_queue_w, &ao, 1);
                }
            }
            else {
                if (do_print_msgs)
                    printf("MessageType: %c\n", m->MessageType);
            }

            pkt_offset += msg_len + 2;
        }

        if (matched_filter) {
            matching_cnt++;
            buf = ring_buf_next();
        }
        else if (do_assert_match_filter) {
            fprintf(stderr, "Warning: message did not match filter!\n");
        }

        if (max_packets && pkt_cnt == max_packets)
            break;
    }

    cleanup_and_exit();

    return 0;
}
