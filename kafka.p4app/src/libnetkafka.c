#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <time.h>

#include "netkafka.h"

void error(char *msg) {
    perror(msg);
    exit(0);
}

unsigned long long ns_since_midnight() {
    struct timespec ts;
    if (clock_gettime(CLOCK_REALTIME, &ts) != 0)
        error("clock_gettime()");
    return ((ts.tv_sec % 86400) * 1e9) + ts.tv_nsec;
}

struct netkafka_client* netkafka_producer_new(char *hostname, int port) {
    struct netkafka_client *cl = (struct netkafka_client*)malloc(sizeof netkafka_client);
    assert(cl != NULL);

    cl->sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (cl->sockfd < 0)
        error("socket()");

    struct hostent *server = gethostbyname(hostname);
    if (server == NULL) {
        fprintf(stderr, "bad hostname: %s\n", hostname);
        exit(0);
    }

    // Check if the remote address is bcast
    uint8_t *last_oct = (uint8_t*)server->h_addr + server->h_length-1;
    //if (strcmp(hostname, "255.255.255.255") == 0) {
    if (*last_oct == 255) {
        int enable_bcast = 1;
        if (setsockopt(cl->sockfd, SOL_SOCKET, SO_BROADCAST, &enable_bcast, sizeof(int)) < 0)
            error("setsockopt() SO_BROADCAST");
    }

    bzero((char *) &cl->remoteaddr, sizeof(cl->remoteaddr));
    cl->remoteaddr.sin_family = AF_INET;
    bcopy((char *)server->h_addr,
            (char *)&cl->remoteaddr.sin_addr.s_addr, server->h_length);
    cl->remoteaddr.sin_port = htons(port);

    return cl;
}


int netkafka_produce(struct netkafka_client *cl, uint32_t topic,
        char *payload, size_t payload_len) {
    int n;

    bzero(cl->buf, NETKAFKA_BUFSIZE);

    struct netkafka_hdr *hdr = (struct netkafka_hdr *)cl->buf;
    hdr->msg_type = MSG_TYPE_DATA;
    hdr->topic = htonl(topic);
    //hdr->timestamp = ns_since_midnight();

    size_t msg_len = sizeof(struct netkafka_hdr) + payload_len;
    assert(msg_len <= NETKAFKA_BUFSIZE);

    memcpy(cl->buf + sizeof(struct netkafka_hdr), payload, payload_len);

    n = sendto(cl->sockfd, cl->buf, msg_len, 0,
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

    //int rcvbuf = 67108864;
    int rcvbuf = 16777216;
    if (setsockopt(cl->sockfd, SOL_SOCKET, SO_RCVBUF, &rcvbuf, sizeof(rcvbuf)) < 0)
        error("setsockopt()");

    return cl;
}

int netkafka_consume(struct netkafka_client *cl, char *payload, size_t *payload_len) {
    int n;

    struct netkafka_hdr *hdr = (struct netkafka_hdr *)cl->buf;

    n = recvfrom(cl->sockfd, hdr, NETKAFKA_BUFSIZE, 0,
            (struct sockaddr *)&cl->remoteaddr, &cl->remoteaddr_len);
    if (n < 0)
        error("recvfrom()");

    assert(hdr->msg_type == MSG_TYPE_DATA);

    //unsigned latency = ns_since_midnight() - hdr->timestamp;
    //printf("latency %u\n", latency);

    *payload_len = n - sizeof(struct netkafka_hdr);

    memcpy(payload, cl->buf+sizeof(struct netkafka_hdr), *payload_len);

    return 1;
}
