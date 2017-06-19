#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "netkafka.h"

void error(char *msg) {
    perror(msg);
    exit(0);
}

struct netkafka_client* netkafka_producer_new(char *hostname, int port) {
    struct netkafka_client *cl = (struct netkafka_client*)malloc(sizeof netkafka_client);

    cl->sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (cl->sockfd < 0)
        error("socket()");

    if (strcmp(hostname, "255.255.255.255") == 0) {
        int enable_bcast = 1;
        if (setsockopt(cl->sockfd, SOL_SOCKET, SO_BROADCAST, &enable_bcast, sizeof(int)) < 0)
            error("setsockopt() SO_BROADCAST");
    }

    struct hostent *server = gethostbyname(hostname);
    if (server == NULL) {
        fprintf(stderr, "bad hostname: %s\n", hostname);
        exit(0);
    }

    bzero((char *) &cl->remoteaddr, sizeof(cl->remoteaddr));
    cl->remoteaddr.sin_family = AF_INET;
    bcopy((char *)server->h_addr,
            (char *)&cl->remoteaddr.sin_addr.s_addr, server->h_length);
    cl->remoteaddr.sin_port = htons(port);
}


int netkafka_produce(struct netkafka_client *cl, unsigned long tag,
        char *payload, size_t payload_len) {
    int n;
    bzero(cl->buf, NETKAFKA_BUFSIZE);

    // TODO: add support for 32-byte tags
    struct netkafka_hdr *hdr = (struct netkafka_hdr *)cl->buf;
    *(unsigned long *)(&hdr->tag[28]) = htonl(tag);

    memcpy(cl->buf + sizeof(struct netkafka_hdr), payload, payload_len);
    unsigned pkt_len = sizeof(struct netkafka_hdr) + payload_len;

    n = sendto(cl->sockfd, cl->buf, pkt_len, 0,
            (struct sockaddr *)&cl->remoteaddr, sizeof(cl->remoteaddr));
    if (n < 0)
      error("sendto()");

    return n;
}

struct netkafka_client* netkafka_consumer_new(int port) {
    struct netkafka_client *cl = (struct netkafka_client*)malloc(sizeof netkafka_client);

    cl->sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (cl->sockfd < 0)
        error("socket()");


    int optval = 1;
    setsockopt(cl->sockfd, SOL_SOCKET, SO_REUSEADDR,
            (const void *)&optval , sizeof(int));

    bzero((char *)&cl->localaddr, sizeof(cl->localaddr));
    cl->localaddr.sin_family = AF_INET;
    cl->localaddr.sin_addr.s_addr = htonl(INADDR_ANY);
    cl->localaddr.sin_port = htons(port);

    if (bind(cl->sockfd, (struct sockaddr *)&cl->localaddr, sizeof(cl->localaddr)) < 0)
        error("bind()");

    return cl;
}

int netkafka_consume(struct netkafka_client *cl, char *payload, size_t *payload_len) {
    int n;

    cl->remoteaddr_len = sizeof(cl->remoteaddr);

    n = recvfrom(cl->sockfd, cl->buf, NETKAFKA_BUFSIZE, 0,
            (struct sockaddr *)&cl->remoteaddr, &cl->remoteaddr_len);
    if (n < 0)
      error("recvfrom()");

    *payload_len = n - sizeof(struct netkafka_hdr);

    memcpy(payload, cl->buf+sizeof(struct netkafka_hdr), *payload_len);

    return 1;
}
