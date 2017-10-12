#include <time.h>
#include <inttypes.h>
#include <string.h>
#include <arpa/inet.h>
#include "libtrading/proto/nasdaq_itch50_message.h"

#define STOCK_SIZE 8

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

// Source: https://stackoverflow.com/questions/3022552/is-there-any-standard-htonl-like-function-for-64-bits-integers-in-c
#define htonll(x) ((1==htonl(1)) ? (x) : ((uint64_t)htonl((x) & 0xFFFFFFFF) << 32) | htonl((x) >> 32))
#define ntohll(x) ((1==ntohl(1)) ? (x) : ((uint64_t)ntohl((x) & 0xFFFFFFFF) << 32) | ntohl((x) >> 32))

#define ntoh48(x) ((1==ntohl(1)) ? (x) : ((uint64_t)ntohl(*((uint32_t *)(&x))) << 16) | ntohs(*((uint16_t *)(((void *)(&x))+4)) ))

void print_add_order_header() {
    printf("MessageType\tStockLocate\tTrackingNumber\tTimestamp\tOrderReferenceNumber\tBuySellIndicator\tShares\tStock\tPrice\n");
}

void print_add_order(struct itch50_msg_add_order *ao) {
    printf("%c\t%u\t%u\t%lu\t%lu\t%c\t%u\t%.*s\t%u\n",
            ao->MessageType, ntohs(ao->StockLocate), ntohs(ao->TrackingNumber),
            ntoh48(*((uint64_t *)ao->Timestamp)),
            ntohll(ao->OrderReferenceNumber),
            ao->BuySellIndicator, ntohl(ao->Shares), 8, ao->Stock, ntohl(ao->Price));
}

void parse_host_port(char *s, int is_port_default, char *parsed_host, short *host_ok, int *parsed_port, short *port_ok) {
    if (s[0] == ':') {
        *parsed_port = atoi(s+1);
        *port_ok = 1; *host_ok = 0;
    }
    else if (!strchr(s, ':')) {
        if (is_port_default) {
            *parsed_port = atoi(s);
            *port_ok = 1; *host_ok = 0;
        }
        else {
            strcpy(parsed_host, s);
            *port_ok = 0; *host_ok = 1;
        }

    }
    else if (sscanf(s, "%[^:]:%d", parsed_host, parsed_port) == 2) {
        *port_ok = 1; *host_ok = 1;
    }
    else {
        *port_ok = 0; *host_ok = 0;
    }
}


struct __attribute__((__packed__)) log_record {
    char sent_ns_since_midnight[6];         // Big-endian (network)
    char received_ns_since_midnight[6];     // Big-endian (network)
    char stock[8];
};

int is_pow2(unsigned n) {
    while (n > 1 && (n & 1) == 0)
        n >>= 1;
    return (n == 1);
}
