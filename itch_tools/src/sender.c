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

void error(char *msg) {
    perror(msg);
    exit(0);
}

#define BUFSIZE 2048
char buf[BUFSIZE];
struct sockaddr_in remoteaddr;

int setup_sender_sock(char *hostname, int port) {

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

    return sockfd;
}



int send_itch_msg(int sockfd) {

    struct omx_moldudp_header *h = (struct omx_moldudp_header *)buf;

    struct omx_moldudp_message *mm = (struct omx_moldudp_message *) (buf + sizeof(struct omx_moldudp_header));

    struct itch41_msg_stock_directory *m = (struct itch41_msg_stock_directory *)(buf + sizeof(struct omx_moldudp_header) + sizeof(struct omx_moldudp_message));

    h->Session[7] = 42;
    h->SequenceNumber = 1;
    h->MessageCount = 1;

    mm->MessageLength = sizeof(struct itch41_msg_stock_directory);

    m->MessageType = ITCH41_MSG_STOCK_DIRECTORY;
    m->MarketCategory = 'a';

    size_t pkt_size = sizeof(struct omx_moldudp_header) + sizeof(struct omx_moldudp_message) + sizeof(struct itch41_msg_stock_directory);

    int n = sendto(sockfd, buf, pkt_size, 0,
            (struct sockaddr *)&remoteaddr, sizeof(remoteaddr));
    if (n < 0)
      error("sendto()");

    return n;
}

int main(int argc, char *argv[]) {
    int sockfd, n;

    char *hostname = argv[1];
    int port = atoi(argv[2]);

    sockfd = setup_sender_sock(hostname, port);

    send_itch_msg(sockfd);


    return 0;
}
