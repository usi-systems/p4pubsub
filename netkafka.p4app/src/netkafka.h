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
    int serverlen;
    struct sockaddr_in serveraddr;
    char buf[NETKAFKA_BUFSIZE];
} netkafka_client;

struct netkafka_client* netkafka_client_new(char *hostname, int port);
int netkafka_client_send(struct netkafka_client *cl, unsigned long tag,
        char *payload, unsigned payload_len);

#endif // __NETKAFKA_H__
