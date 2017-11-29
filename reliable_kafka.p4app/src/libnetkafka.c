#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <pthread.h>

#include "netkafka.h"

void error(char *msg) {
    perror(msg);
    exit(0);
}

#define MSG_TYPE_DATA           1
#define MSG_TYPE_MISSING        2
#define MSG_TYPE_RETRANS_REQ    3

const char *netkafka_msg_name(uint8_t msg_type) {
    switch (msg_type) {
        case MSG_TYPE_DATA:
            return "MSG";
        case MSG_TYPE_RETRANS_REQ:
            return "RETRREQ";
        case MSG_TYPE_MISSING:
            return "MISSING";
        default:
            assert(0 && "bad msg_type");
    }
}

void netkafka_retransmit_req(struct netkafka_client *cl, int from, int to) {
    struct netkafka_hdr hdr;
    int n;
    hdr.msg_type = MSG_TYPE_RETRANS_REQ;
    hdr.seq1 = htonl(from);
    hdr.seq2 = htonl(to);

    printf("    <- RTREQ{seq1: %d, seq2: %d}\n", from, to);

    n = sendto(cl->sockfd, &hdr, sizeof(hdr), 0,
                (struct sockaddr *)&cl->retraddr, sizeof(cl->retraddr));
    if (n < 0)
        error("sendto()");
}

void netkafka_retransmit(struct netkafka_client *cl, int from, int to) {
    uint32_t seq;
    int n;
    for (seq = from; seq <= to; seq++) {
        int idx = seq % cl->ring_buf_items;

        char *buf = cl->ring_buf + (idx * NETKAFKA_BUFSIZE);
        size_t *msg_len = cl->ring_buf_sizes + idx;

        n = sendto(cl->sockfd, buf, *msg_len, 0,
                (struct sockaddr *)&cl->remoteaddr, sizeof(cl->remoteaddr));
        if (n < 0)
          error("sendto()");
    }
}

void *netkafka_retransmitter(void *arg) {
    struct netkafka_client *cl = (struct netkafka_client *)arg;
    int n;
    struct sockaddr_in addr;
    int addr_len = sizeof(addr);

    cl->retr_sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (cl->retr_sockfd < 0)
        error("socket()");

    int optval = 1;
    setsockopt(cl->retr_sockfd, SOL_SOCKET, SO_REUSEADDR,
            (const void *)&optval , sizeof(int));

    bzero((char *)&addr, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    addr.sin_port = htons(cl->retr_port);

    if (bind(cl->retr_sockfd, (struct sockaddr *)&addr, sizeof(addr)) < 0)
        error("bind()");

    char buf[NETKAFKA_BUFSIZE];
    struct netkafka_hdr *hdr = (struct netkafka_hdr *)buf;

    printf("Retransmit thread running.\n");
    while (1) {
        n = recvfrom(cl->retr_sockfd, hdr, NETKAFKA_BUFSIZE, 0,
                (struct sockaddr *)&addr, &addr_len);
        if (n < 0)
          error("recvfrom()");

        assert(hdr->msg_type == MSG_TYPE_RETRANS_REQ);

        uint32_t seq1 = ntohl(hdr->seq1);
        uint32_t seq2 = ntohl(hdr->seq2);
        printf("-> RETR{seq1: %d, seq2: %d}\n", seq1, seq2);

        assert(seq1 <= cl->seq && "Cannot retrans a seq we haven't sent yet");
        assert(seq2 <= cl->seq && "Cannot retrans a seq we haven't sent yet");
        assert(((int)cl->seq - cl->ring_buf_items) <= (int)seq1 && "Requested seq is outside of hist");

        netkafka_retransmit(cl, seq1, seq2);
    }

    close(cl->retr_sockfd);
}

struct netkafka_client* netkafka_producer_new(char *hostname, int port) {
    struct netkafka_client *cl = (struct netkafka_client*)malloc(sizeof netkafka_client);
    assert(cl != NULL);

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

    cl->seq = 0; cl->last_seq = 0;
    cl->ring_buf_items = 10000;
    cl->ring_buf = (char *)malloc(NETKAFKA_BUFSIZE * cl->ring_buf_items);
    cl->ring_buf_sizes = (size_t *)malloc(sizeof(size_t) * cl->ring_buf_items);
    bzero(cl->ring_buf_sizes, sizeof(size_t) * cl->ring_buf_items);

    cl->retr_port = 4321;
    if (pthread_create(&cl->retr_thread, NULL, netkafka_retransmitter, cl)) {
        error("pthread_create()");
    }

    return cl;
}


int netkafka_produce(struct netkafka_client *cl, uint32_t topic,
        char *payload, size_t payload_len) {
    int n;

    cl->seq++;

    char *send_buf = cl->ring_buf + (cl->seq % cl->ring_buf_items)*NETKAFKA_BUFSIZE;
    size_t *msg_len = cl->ring_buf_sizes + (cl->seq % cl->ring_buf_items);
    bzero(send_buf, NETKAFKA_BUFSIZE);

    struct netkafka_hdr *hdr = (struct netkafka_hdr *)send_buf;
    hdr->msg_type = MSG_TYPE_DATA;
    hdr->topic = htonl(topic);
    hdr->seq1 = htonl(cl->seq);

    *msg_len = sizeof(struct netkafka_hdr) + payload_len;
    assert(*msg_len <= NETKAFKA_BUFSIZE);

    memcpy(send_buf + sizeof(struct netkafka_hdr), payload, payload_len);

    //if (cl->seq == 1) return *msg_len; // upstream drop seq 1

    n = sendto(cl->sockfd, send_buf, *msg_len, 0,
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

    char *hostname = "10.0.3.101";
    struct hostent *server = gethostbyname(hostname);
    if (server == NULL) {
        fprintf(stderr, "bad hostname: %s\n", hostname);
        exit(0);
    }

    bzero((char *) &cl->retraddr, sizeof(cl->retraddr));
    cl->retraddr.sin_family = AF_INET;
    bcopy((char *)server->h_addr,
            (char *)&cl->retraddr.sin_addr.s_addr, server->h_length);
    cl->retraddr.sin_port = htons(4321);

    if (bind(cl->sockfd, (struct sockaddr *)&cl->localaddr, sizeof(cl->localaddr)) < 0)
        error("bind()");

    cl->seq = 0; cl->last_seq = 0;
    cl->delivered_seq = 0;
    cl->ring_buf_items = 1000;
    cl->ring_buf = (char *)malloc(NETKAFKA_BUFSIZE * cl->ring_buf_items);
    cl->ring_buf_sizes = (size_t *)malloc(sizeof(size_t) * cl->ring_buf_items);
    bzero(cl->ring_buf_sizes, sizeof(size_t) * cl->ring_buf_items);

    return cl;
}

int netkafka_consume(struct netkafka_client *cl, char *payload, size_t *payload_len) {
    int n;

    int idx = cl->delivered_seq % cl->ring_buf_items;
    if (cl->ring_buf_sizes[idx+1] > 0) {
        char *buf = cl->ring_buf + (idx * NETKAFKA_BUFSIZE);
        *payload_len = cl->ring_buf_sizes[idx+1] - sizeof(struct netkafka_hdr);
        memcpy(payload, cl->ring_buf+sizeof(struct netkafka_hdr), *payload_len);

        cl->ring_buf_sizes[idx+1] = 0; // remove item from ring buf
        // TODO: how do we have a re-order queue?
        cl->delivered_seq;

        return 1;
    }

    struct netkafka_hdr *hdr = (struct netkafka_hdr *)cl->buf;

    while (1) {
        n = recvfrom(cl->sockfd, hdr, NETKAFKA_BUFSIZE, 0,
                (struct sockaddr *)&cl->remoteaddr, &cl->remoteaddr_len);
        if (n < 0)
          error("recvfrom()");

        uint32_t seq1 = ntohl(hdr->seq1);
        uint32_t seq2 = ntohl(hdr->seq2);
        uint32_t topic_or_seq3 = ntohl(hdr->topic);

        //if (seq2 == 2) continue; // downstream drop seq 2

        printf("-> %s{seq1: %d, seq2: %d, seq3: %d}\n", netkafka_msg_name(hdr->msg_type), seq1, seq2, topic_or_seq3);

        if (cl->seq == 0 || seq2 == cl->last_seq + 1) {
            cl->seq = seq1;
            cl->last_seq = seq2;
        }

        if (seq2 > cl->last_seq) {
            cl->last_seq = seq2;
            int from = cl->seq+1 < seq1 ? cl->seq+1 : seq1;
            int to = cl->seq+1 > seq1 ? cl->seq+1 : seq1;
            netkafka_retransmit_req(cl, from, to);

            idx = seq1 % cl->ring_buf_items;
            char *buf = cl->ring_buf + (idx * NETKAFKA_BUFSIZE);
            memcpy(buf, hdr, n);
            cl->ring_buf_sizes[idx] = n;
            continue;
        }

        if (hdr->msg_type == MSG_TYPE_DATA) {
            if (cl->delivered_seq == 0 || cl->delivered_seq < seq1) {
                cl->delivered_seq = seq1;
                break;
            }
        }
        else if (hdr->msg_type == MSG_TYPE_MISSING) {
            netkafka_retransmit_req(cl, seq1, topic_or_seq3);
        }
        else {
            assert(0 && "Bad msg_type");
        }

    }

    *payload_len = n - sizeof(struct netkafka_hdr);

    memcpy(payload, cl->ring_buf+sizeof(struct netkafka_hdr), *payload_len);

    return 1;
}
