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

char *my_hostname;

char *progname;

int fd_log = -1;
int recv_cnt = 0;

void error(char *msg) {
    perror(msg);
    exit(0);
}

void usage(int rc) {
    fprintf(rc == 0 ? stdout : stderr,
            "Usage: %s [-a OPTIONS] [-b SO_RCVBUF] [-t LOG_FILENAME] [-l LISTEN_HOST -p LISTEN_PORT] CONTROLLER_HOST CONTROLLER_PORT STOCKS\n\
\n\
OPTIONS is a string of chars, which can include:\n\
\n\
    q - exit after subcribing to controller\n\
    a - print Add Order messages as TSV\n\
    o - print other message types\n\
    s - don't send subscription request to controller\n\
\n\
", progname);
    exit(rc);
}

void catch_int(int signo) {
    if (fd_log) {
        close(fd_log);
    }
    fprintf(stderr, "Received %d messages\n", recv_cnt);
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
    if (!my_hostname) {
        fprintf(stderr, "Cannot send subcription request without my hostname (-h)\n");
        usage(-1);
    }
    int len = sprintf(msg, "sub\t%s\t%s\n", my_hostname, stocks);
    send_to_controller(controller_hostname, port, msg, len);
}


int main(int argc, char *argv[]) {
    int opt;
    char *stocks_with_commas = 0;
    char *controller_hostname = 0;
    char *log_filename = 0;
    char *extra_options = 0;
    int controller_port = 0;
    my_hostname = "127.0.0.1";
    int port = 1234;
    int dont_listen = 0;
    int dont_subscribe = 0;
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

    progname = basename(argv[0]);

    while ((opt = getopt(argc, argv, "ha:b:t:l:p:")) != -1) {
        switch (opt) {
            case 'a':
                extra_options = optarg;
                break;
            case 'b':
                rcvbuf = atoi(optarg);
                break;
            case 't':
                log_filename = optarg;
                break;
            case 'p':
                port = atoi(optarg);
                break;
            case 'l':
                my_hostname = optarg;
                break;
            case 'h':
                usage(0);
            default: /* '?' */
                usage(-1);
        }
    }

    if (argc - optind != 3)
        usage(-1);

    controller_hostname = argv[optind];
    controller_port = atoi(argv[optind+1]);
    stocks_with_commas = argv[optind+2];

    if (extra_options) {
        if (strchr(extra_options, 'q'))
            dont_listen = 1;
        if (strchr(extra_options, 's'))
            dont_subscribe = 1;
        if (strchr(extra_options, 'a'))
            do_print_ao = 1;
        if (strchr(extra_options, 'o'))
            do_print_msgs = 1;
    }

    if (!controller_hostname || !controller_port) {
        fprintf(stderr, "Invalid controller hostname or port\n");
        usage(-1);
    }

    if (!stocks_with_commas) {
        fprintf(stderr, "Invalid stocks\n");
        usage(-1);
    }

    if (log_filename) {
        fd_log = open(log_filename, O_WRONLY | O_CREAT | O_TRUNC, 0664);
        if (fd_log < 0)
            error("open() log_filename");
    }

    signal(SIGINT, catch_int);



    int sockfd, i, n;
    struct sockaddr_in localaddr;
    struct sockaddr_in remoteaddr;
    char buf[BUFSIZE];

    if (!dont_subscribe)
        subscribe_to_stocks(controller_hostname, controller_port, stocks_with_commas);

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

    if (rcvbuf > 0) {
        if (setsockopt(sockfd, SOL_SOCKET, SO_RCVBUF, &rcvbuf, sizeof(rcvbuf)) < 0)
            error("setsockopt()");
    }

    int remoteaddr_len = sizeof(remoteaddr);

    while (1) {
        n = recvfrom(sockfd, buf, BUFSIZE, 0,
                (struct sockaddr *)&remoteaddr, &remoteaddr_len);
        if (n < 0)
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


    }

    return 0;
}
