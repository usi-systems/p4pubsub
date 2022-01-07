#include <inttypes.h>

struct __attribute__((__packed__)) car_tracker_hdr {
    uint16_t lat;
    uint16_t lon;
    uint16_t speed;
};
