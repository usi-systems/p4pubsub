#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "netkafka.h"

void error(char *msg) {
    perror(msg);
    exit(0);
}

struct netkafka_client* netkafka_client_new(char *hostname, int port) {
    struct netkafka_client *cl = (struct netkafka_client*)malloc(sizeof netkafka_client);

    cl->sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (cl->sockfd < 0)
        error("ERROR opening socket");

    struct hostent *server = gethostbyname(hostname);
    if (server == NULL) {
        fprintf(stderr,"ERROR, no such host as %s\n", hostname);
        exit(0);
    }

    bzero((char *) &cl->serveraddr, sizeof(cl->serveraddr));
    cl->serveraddr.sin_family = AF_INET;
    bcopy((char *)server->h_addr,
            (char *)&cl->serveraddr.sin_addr.s_addr, server->h_length);
    cl->serveraddr.sin_port = htons(port);
    cl->serverlen = sizeof(cl->serveraddr);
}

int netkafka_client_send(struct netkafka_client *cl, unsigned long tag,
        char *payload, unsigned payload_len) {
    int n;
    bzero(cl->buf, NETKAFKA_BUFSIZE);

    // TODO: add support for 32-byte tags
    struct netkafka_hdr *hdr = (struct netkafka_hdr *)cl->buf;
    *(unsigned long *)(&hdr->tag[28]) = htonl(tag);

    memcpy(cl->buf + sizeof(struct netkafka_hdr), payload, payload_len);
    unsigned pkt_len = sizeof(struct netkafka_hdr) + payload_len;

    n = sendto(cl->sockfd, cl->buf, pkt_len, 0,
            (struct sockaddr *)&cl->serveraddr, cl->serverlen);
    if (n < 0)
      error("ERROR in sendto");

    return n;
}
