#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <string.h>

#include "libtrading/proto/nasdaq_itch41_message.h"
#include "libtrading/proto/omx_moldudp_message.h"

#define BUFSIZE 2048

void error(char *msg) {
    perror(msg);
    exit(0);
}

int main(int argc, char *argv[]) {
    int sockfd;
    struct sockaddr_in localaddr;
    struct sockaddr_in remoteaddr;
    char buf[BUFSIZE];

    int port = atoi(argv[1]);

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
    int n;


    while (1) {
        n = recvfrom(sockfd, buf, BUFSIZE, 0,
                (struct sockaddr *)&remoteaddr, &remoteaddr_len);
        if (n < 0)
            error("recvfrom()");

        struct omx_moldudp_header *h = (struct omx_moldudp_header *)buf;
        struct omx_moldudp_message *mm = (struct omx_moldudp_message *) (buf + sizeof(struct omx_moldudp_header));

        struct itch41_msg_add_order *m = (struct itch41_msg_add_order *)(buf + sizeof(struct omx_moldudp_header) + sizeof(struct omx_moldudp_message));

        printf("Session: %d\nType: %c\nBuySellIndicator: %d\n", h->Session[7], m->MessageType, m->BuySellIndicator);
        fflush(stdout);

    }


    return 0;
}
