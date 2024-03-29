#ifndef __HEADER_P4__
#define __HEADER_P4__ 1

struct ingress_metadata_t {
    bit<32> nhop_ipv4;
}

struct intrinsic_metadata_t {
    bit<48> ingress_global_timestamp;
    bit<32> lf_field_list;
    bit<16> mcast_grp;
    bit<16> egress_rid;
}

header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

header ipv4_t {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<32> srcAddr;
    bit<32> dstAddr;
}

header udp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<16> length_;
    bit<16> checksum;
}

header tag_t {
    bit<32> tag;
    bit<8> flag;
}


struct metadata {
    ingress_metadata_t   ingress_metadata;
    intrinsic_metadata_t intrinsic_metadata;
}

struct headers {
    ethernet_t ethernet;
    ipv4_t     ipv4;
    udp_t      udp;
    tag_t      tag;
}

#endif // __HEADER_H__
