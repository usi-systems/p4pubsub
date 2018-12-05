#include <inttypes.h>

const uint32_t int_probe_marker1 = 0xefbeadde;
const uint32_t int_probe_marker2 = 0x0df0ad8b;

struct __attribute__((__packed__)) int_probe_marker {
    uint32_t marker1;
    uint32_t marker2;
};

struct __attribute__((__packed__)) intl4_shim {
    uint8_t int_type;
    uint8_t rsvd1;
    uint8_t len;
    uint8_t dscp_rsvd2;
};

/* INT header */
/* 16 instruction bits are defined in four 4b fields to allow concurrent
lookups of the bits without listing 2^16 combinations */
struct __attribute__((__packed__)) int_header {
    uint8_t ver_rep_c_e;
    uint8_t m_rsvd1;
    uint8_t rsvd2_hop_metadata_len;
    uint8_t remaining_hop_cnt;
    uint8_t instruction_mask_0007;
    uint8_t instruction_mask_0815;
    uint16_t rsvd3;
};

struct __attribute__((__packed__)) int_switch_id { // instruction bit0
    uint32_t switch_id;
};

struct __attribute__((__packed__)) int_hop_latency { // instruction bit2
    uint32_t hop_latency;
};

struct __attribute__((__packed__)) int_q_occupancy { // instruction bit3
    uint8_t q_id;
    uint8_t q_occupancy1;
    uint8_t q_occupancy2;
    uint8_t q_occupancy3;
};
