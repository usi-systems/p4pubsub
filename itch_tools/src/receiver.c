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

#include "libtrading/proto/nasdaq_itch50_message.h"
#include "libtrading/proto/omx_moldudp_message.h"
#include "../third-party/libtrading/lib/proto/nasdaq_itch50_message.c"

#include "common.c"

#define BUFSIZE 2048

char listen_hostname[256];

char *progname;

int verbosity = 0;

int sockfd;
int fd_log = -1;
int recv_cnt = 0;

void error(char *msg) {
    perror(msg);
    exit(0);
}

void usage(int rc) {
    fprintf(rc == 0 ? stdout : stderr,
            "Usage: %s [-v VERBOSITY] [-a OPTIONS] [-b SO_RCVBUF] [-t LOG_FILENAME] [-f FWD_HOST:PORT] [-c CONTROLLER_HOST:PORT] [-s STOCKS] [[LISTEN_HOST:]PORT]\n\
\n\
OPTIONS is a string of chars, which can include:\n\
\n\
    q - exit after subcribing to controller\n\
    a - print Add Order messages as TSV\n\
    o - print other message types\n\
\n\
", progname);
    exit(rc);
}

void catch_int(int signo) {
    if (fd_log) {
        close(fd_log);
        close(sockfd);
    }
    fprintf(stderr, "\nReceived %d messages\n", recv_cnt);
    exit(0);
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

void subscribe_to_stocks(char *controller_hostname, int port, char *stocks) {
    char msg[2048];
    if (!listen_hostname) {
        fprintf(stderr, "Cannot send subcription request without my hostname (-h)\n");
        usage(-1);
    }
    int len = sprintf(msg, "sub\t%s\t%s\n", listen_hostname, stocks);
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
    int do_print_msgs = 0;
    int rcvbuf = 0;
    int msg_num;
    short msg_count;
    int msg_len;
    int pkt_offset;
    unsigned long long timestamp;
    struct omx_moldudp64_header *h;
    struct omx_moldudp64_message *mm;
    struct itch50_message *m;
    struct itch50_msg_add_order *ao;
    struct sockaddr_in forward_addr;

    progname = basename(argv[0]);

    while ((opt = getopt(argc, argv, "hv:a:b:t:f:s:c:")) != -1) {
        switch (opt) {
            case 'a':
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
    }

    if (controller_host_port) {
        parse_host_port(listen_host_port, 0, controller_hostname, &host_ok, &controller_port, &port_ok);
        if (!host_ok)
            strcpy(controller_hostname, "127.0.0.1");
        if (!port_ok)
            controller_port = 9090;
    }

    if (log_filename) {
        fd_log = open(log_filename, O_WRONLY | O_CREAT | O_TRUNC, 0664);
        if (fd_log < 0)
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



    int i, bytes_received;
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
    }

    int remoteaddr_len = sizeof(remoteaddr);

    while (1) {
        bytes_received = recvfrom(sockfd, buf, BUFSIZE, 0,
                (struct sockaddr *)&remoteaddr, &remoteaddr_len);
        if (bytes_received < 0)
            error("recvfrom()");
        recv_cnt++;

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
                if (do_print_ao)
                    print_add_order(ao);
                if (fd_log) {
                    timestamp = ns_since_midnight();
                    write(fd_log, ao->Timestamp, 6);
                    write(fd_log, &timestamp, 6);
                    write(fd_log, ao->Stock, 8);
                }
            }
            else {
                if (do_print_msgs)
                    printf("MessageType: %c\n", m->MessageType);
            }

            pkt_offset += msg_len + 2;
        }

        if (forward_host_port) {
            if (sendto(sockfd, buf, bytes_received, 0,
                        (struct sockaddr *)&forward_addr, sizeof(forward_addr)) < 0)
                error("sendto()");
        }


    }

    return 0;
}
