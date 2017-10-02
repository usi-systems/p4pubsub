#include <stdio.h>
#include <stdlib.h>
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

#include "libtrading/proto/nasdaq_itch50_message.h"
#include "libtrading/proto/omx_moldudp_message.h"
#include "../third-party/libtrading/lib/proto/nasdaq_itch50_message.c"

#include "common.c"

#define BUFSIZE 2048

char listen_hostname[256];

char *progname;

int verbosity = 0;

int sockfd = 0;
FILE *fh_log = 0;
int pkt_cnt = 0;
int matching_cnt = 0;

void usage(int rc) {
    fprintf(rc == 0 ? stdout : stderr,
            "Usage: %s [-v VERBOSITY] [-o OPTIONS] [-b SO_RCVBUF] [-m MAX_PKTS] [-t LOG_FILENAME] [-f FWD_HOST:PORT] [-c CONTROLLER_HOST[:PORT]] [-s STOCKS] [[LISTEN_HOST:]PORT]\n\
\n\
OPTIONS is a string of chars, which can include:\n\
\n\
    q - exit after subcribing to controller\n\
    a - print Add Order messages as TSV\n\
    o - print other message types\n\
    u - update timestamp when forwarding message\n\
    i - ignore filter\n\
    A - assert that all messages match the filter\n\
\n\
", progname);
    exit(rc);
}

void cleanup_and_exit() {
    if (fh_log)
        fclose(fh_log);

    if (sockfd)
        close(sockfd);

    fprintf(stderr, "\nReceived %d packets (%d matched filter)\n", pkt_cnt, matching_cnt);
    exit(0);
}

void catch_int(int signo) {
    cleanup_and_exit();
}

void send_to_controller(char *hostname, int port, char *msg, size_t len) {
    struct sockaddr_in remoteaddr;

    int sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0)
        error("socket()");

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

    if (connect(sockfd, (struct sockaddr *)&remoteaddr, sizeof(remoteaddr)) < 0)
        error("connect()");

    int n = write(sockfd, msg, len);
    if (n < 0)
      error("write()");

    close(sockfd);
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

void subscribe_to_stocks(char *controller_hostname, int port, char *stocks_with_commas) {
    char msg[2048];
    if (!listen_hostname) {
        fprintf(stderr, "Cannot send subcription request without my hostname (-h)\n");
        usage(-1);
    }
    int len = sprintf(msg, "sub\t%s\t%s\n", listen_hostname, stocks_with_commas);
    send_to_controller(controller_hostname, port, msg, len);
}


int main(int argc, char *argv[]) {
    int opt;
    char *stocks_with_commas = 0;
    char *controller_host_port = 0;
    char *listen_host_port = 0;
    char controller_hostname[256];
    char forward_hostname[256];
    int forward_port;
    char *forward_host_port = 0;
    int controller_port = 0;
    strcpy(listen_hostname, "127.0.0.1");
    int port;
    short host_ok, port_ok;
    char *log_filename = 0;
    char *extra_options = 0;
    int dont_listen = 0;
    int do_print_ao = 0;
    int do_update_timestamp = 0;
    int do_print_msgs = 0;
    int do_ignore_filter = 0;
    int do_assert_match_filter = 0;
    int rcvbuf = 0;
    int msg_num;
    short msg_count;
    int msg_len;
    int pkt_offset;
    int max_packets = 0;
    unsigned long long timestamp;
    struct omx_moldudp64_header *h;
    struct omx_moldudp64_message *mm;
    struct itch50_message *m;
    struct itch50_msg_add_order *ao;
    struct sockaddr_in forward_addr;

    filtered_stocks.count = 0;

    progname = basename(argv[0]);

    while ((opt = getopt(argc, argv, "hv:o:b:t:f:s:c:m:")) != -1) {
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
            case 't':
                log_filename = optarg;
                break;
            case 'c':
                controller_host_port = optarg;
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


    if (extra_options) {
        if (strchr(extra_options, 'q'))
            dont_listen = 1;
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

    if (controller_host_port) {
        parse_host_port(controller_host_port, 0, controller_hostname, &host_ok, &controller_port, &port_ok);
        if (!host_ok)
            strcpy(controller_hostname, "127.0.0.1");
        if (!port_ok)
            controller_port = 9090;
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
            exit(0);
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
    char buf[BUFSIZE];

    if (controller_host_port) {
        if (!stocks_with_commas) {
            fprintf(stderr, "Invalid stocks\n");
            usage(-1);
        }

        subscribe_to_stocks(controller_hostname, controller_port, stocks_with_commas);
    }

    if (stocks_with_commas)
        parse_stocks_str(stocks_with_commas);

    if (verbosity > 0)
        print_filtered_stocks();

    if (verbosity > 0 && do_ignore_filter)
        printf("Filters will be computed on each packet, but the result will be ignored.\n");


    if (dont_listen)
        exit(0);

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

    while (1) {
        matched_filter = 0;

        size = recvfrom(sockfd, buf, BUFSIZE, 0,
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
                    if (do_print_ao)
                        print_add_order(ao);
                    if (fh_log) {
                        timestamp = ns_since_midnight();
                        fwrite(ao->Timestamp, 6, 1, fh_log);
                        fwrite(&timestamp, 6, 1, fh_log);
                        fwrite(ao->Stock, 8, 1, fh_log);
                    }
                    if (do_update_timestamp) {
                        timestamp = htonll(ns_since_midnight());
                        memcpy(ao->Timestamp, (void*)&timestamp + 2, 6);
                    }
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

            if (forward_host_port) {
                if (sendto(sockfd, buf, size, 0,
                            (struct sockaddr *)&forward_addr, sizeof(forward_addr)) < 0)
                    error("sendto()");
            }
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
