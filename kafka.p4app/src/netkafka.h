#ifndef __NETKAFKA_H__
#define __NETKAFKA_H__

#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>

#define NETKAFKA_BUFSIZE        1200

#define MSG_TYPE_DATA           1

const char *netkafka_msg_name(uint8_t msg_type);

struct __attribute__((__packed__)) netkafka_hdr {
    uint8_t msg_type;
    uint32_t topic;
    uint64_t timestamp;
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
int netkafka_produce(struct netkafka_client *cl, uint32_t topic,
        char *payload, size_t payload_len);
int netkafka_consume(struct netkafka_client *cl, char *payload, size_t *payload_len);

#endif // __NETKAFKA_H__
