#ifndef __NETKAFKA_H__
#define __NETKAFKA_H__

#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>

#define NETKAFKA_BUFSIZE 1024

struct netkafka_hdr {
    char tag[32];
    char flag;
} netkafka_hdr;

struct netkafka_client {
    int sockfd;
    struct sockaddr_in localaddr;
    struct sockaddr_in remoteaddr;
    int remoteaddr_len;
    char buf[NETKAFKA_BUFSIZE];
} netkafka_client;

struct netkafka_client* netkafka_producer_new(char *hostname, int port);
struct netkafka_client* netkafka_consumer_new(int port);
int netkafka_produce(struct netkafka_client *cl, unsigned long tag,
        char *payload, size_t payload_len);
int netkafka_consume(struct netkafka_client *cl, char *payload, size_t *payload_len);

#endif // __NETKAFKA_H__
