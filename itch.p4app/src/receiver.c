#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <string.h>

#include "libtrading/proto/nasdaq_itch50_message.h"
#include "libtrading/proto/omx_moldudp_message.h"
#include "../third-party/libtrading/lib/proto/nasdaq_itch50_message.c"

#define BUFSIZE 2048

char *my_hostname;

#define MAX_STOCKS 24

char subscribe_stocks[MAX_STOCKS][8];

void error(char *msg) {
    perror(msg);
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

void subscribe_to_stock(char *controller_hostname, int port, char *stock) {
    char msg[2048];
    int len = sprintf(msg, "sub,%s,%s\n", my_hostname, stock);
    send_to_controller(controller_hostname, port, msg, len);
}

void parse_stocks(const char *stocks) {
    bzero(subscribe_stocks[0], sizeof(char)*MAX_STOCKS*8);

    const char *start = stocks;
    const char *end = start;

    for (int i = 0; *end != '\0' && i < MAX_STOCKS; i++) {
        end = strchr(start, ',');
        if (end == NULL) end = strchr(start, '\0');
        memcpy(subscribe_stocks[i], start, end-start);
        start = end+1;
    }
}

int main(int argc, char *argv[]) {
    int sockfd, i, n;
    struct sockaddr_in localaddr;
    struct sockaddr_in remoteaddr;
    char buf[BUFSIZE];

    char *stocks_with_commas = argv[1];
    char *controller_hostname = argv[2];
    int controller_port = atoi(argv[3]);
    my_hostname = argv[4];
    int port = atoi(argv[5]);

    parse_stocks(stocks_with_commas);
    for (i = 0; i < MAX_STOCKS; i++) {
        if (subscribe_stocks[i][0] == '\0') break;
        subscribe_to_stock(controller_hostname, controller_port, subscribe_stocks[i]);
    }

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

    int remoteaddr_len = sizeof(remoteaddr);

    while (1) {
        n = recvfrom(sockfd, buf, BUFSIZE, 0,
                (struct sockaddr *)&remoteaddr, &remoteaddr_len);
        if (n < 0)
            error("recvfrom()");

        struct omx_moldudp_header *h = (struct omx_moldudp_header *)buf;
        struct omx_moldudp_message *mm = (struct omx_moldudp_message *) (buf + sizeof(struct omx_moldudp_header));

        struct itch50_message *m = (struct itch50_message *)(buf + sizeof(struct omx_moldudp_header) + sizeof(struct omx_moldudp_message));

        int expected_size = itch50_message_size(m->MessageType);
        if (expected_size != mm->MessageLength)
            fprintf(stderr, "MessageType %c should have size %d, found %d\n", m->MessageType, expected_size, mm->MessageLength);

        if (m->MessageType == ITCH50_MSG_ADD_ORDER) {
            struct itch50_msg_add_order *ao = (struct itch50_msg_add_order *)m;
            printf("Stock: '%s'\n", ao->Stock);
        }

        printf("Session: %d\nType: %c\n", h->Session[7], m->MessageType);
        fflush(stdout);

    }


    return 0;
}
