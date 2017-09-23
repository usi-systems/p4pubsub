#include <sys/time.h>

unsigned long long us_since_midnight() {
    struct timeval tv;
    if (gettimeofday(&tv, NULL) != 0)
        return 0;
    return (tv.tv_sec % 86400) * 1e9 + tv.tv_usec;
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
