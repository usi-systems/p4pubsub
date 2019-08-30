#include <tofino/constants.p4>
#include <tofino/intrinsic_metadata.p4>
#include "tofino/lpf_blackbox.p4"

// *********************************
//            HEADERS
// *********************************

header_type ethernet_t {
    fields {
        dstAddr : 48;
        srcAddr : 48;
        etherType : 16;
    }
}

header_type ipv4_t {
    fields {
        version : 4;
        ihl : 4;
        diffserv : 8;
        totalLen : 16;
        identification : 16;
        flags : 3;
        fragOffset : 13;
        ttl : 8;
        protocol : 8;
        hdrChecksum : 16;
        srcAddr : 32;
        dstAddr: 32;
    }
}

header_type ipv6_t {
    fields {
        version : 4;
        trafficClass : 8;
        flowLabel : 20;
        payloadLen : 16;
        nextHdr : 8;
        hopLimit : 8;
        srcAddr : 128;
        dstAddr : 128;
    }
}

header_type tcp_t {
    fields {
        srcPort : 16;
        dstPort : 16;
        seqNo : 32;
        ackNo : 32;
        dataOffset : 4;
        res : 3;
        ecn : 3;
        ctrl : 6;
        window : 16;
        checksum : 16;
        urgentPtr : 16;
    }
}

header_type udp_t {
    fields {
        srcPort: 16;
        dstPort: 16;
        length_: 16;
        checksum: 16;
    }
}

header_type icmp_t {
    fields {
        typeCode : 16;
        hdrChecksum : 16;
    }
}

header_type icmp_ping_t {
    fields {
        id: 16;
        seqNo0: 8;
        seqNo1: 8;
    }
}

header_type camus_meta_t {
    fields {
        state: 16;
    }
}

header_type stful_t {
    fields {
        color: 8;
    }
}

// *********************************
//            PARSER
// *********************************

parser start {
    return parse_ethernet;
}

#define ETHERTYPE_IPV4 0x0800
#define ETHERTYPE_IPV6 0x86dd
#define IP_PROTOCOLS_ICMP              1
#define IP_PROTOCOLS_TCP               6
#define IP_PROTOCOLS_UDP               17
#define IP_PROTOCOLS_ICMPV6            58

header ethernet_t ethernet;

parser parse_ethernet {
    extract(ethernet);
    return select(latest.etherType) {
        ETHERTYPE_IPV4 : parse_ipv4;
        ETHERTYPE_IPV6 : parse_ipv6;
        default: ingress;
    }
}

header ipv4_t ipv4;
header ipv6_t ipv6;
header tcp_t tcp;
header udp_t udp;
header icmp_t icmp;
header icmp_ping_t icmp_ping;

field_list ipv4_checksum_list {
        ipv4.version;
        ipv4.ihl;
        ipv4.diffserv;
        ipv4.totalLen;
        ipv4.identification;
        ipv4.flags;
        ipv4.fragOffset;
        ipv4.ttl;
        ipv4.protocol;
        ipv4.srcAddr;
        ipv4.dstAddr;
}

field_list_calculation ipv4_checksum {
    input {
        ipv4_checksum_list;
    }
    algorithm : csum16;
    output_width : 16;
}

calculated_field ipv4.hdrChecksum  {
    verify ipv4_checksum;
    update ipv4_checksum;
}

parser parse_ipv4 {
    extract(ipv4);
    return select(latest.protocol) {
        IP_PROTOCOLS_ICMP : parse_icmp;
        IP_PROTOCOLS_TCP : parse_tcp;
        IP_PROTOCOLS_UDP : parse_udp;
        default : ingress;
    }
}

parser parse_ipv6 {
    extract(ipv6);
    return select(latest.nextHdr) {
        IP_PROTOCOLS_ICMPV6 : parse_icmp6;
        IP_PROTOCOLS_TCP : parse_tcp;
        IP_PROTOCOLS_UDP : parse_udp;
        default : ingress;
    }
}

parser parse_tcp {
    extract(tcp);
    return ingress;
}

parser parse_udp {
    extract(udp);
    return ingress;
}

parser parse_icmp {
    extract(icmp);
    return select(latest.typeCode) {
        0x0800 : parse_icmp_ping;
        default : ingress;
    }
}

parser parse_icmp6 {
    extract(icmp);
    return select(latest.typeCode) {
        0x8000 : parse_icmp_ping;
        default : ingress;
    }
}

parser parse_icmp_ping {
    extract(icmp_ping);
    return ingress;
}

metadata camus_meta_t camus_meta;
metadata stful_t stful;


// *********************************
//            INGRESS
// *********************************

action set_next_state(next_state) {
    modify_field(camus_meta.state, next_state);
}

action set_mgid(mgid) {
    modify_field(ig_intr_md_for_tm.mcast_grp_a, mgid);
}

action set_egress_port(port) {
    modify_field(ig_intr_md_for_tm.ucast_egress_port, port);
}

action query_drop() {
    drop();
}

table query_actions {
    reads { camus_meta.state: exact; }
    actions { query_drop; set_egress_port; set_mgid; }
    default_action: query_drop;
    size: 1024;
}

table query_ipv6_dstAddr_lpm {
    reads { camus_meta.state: exact; ipv6.dstAddr: lpm; }
    actions { set_next_state; }
    size: 1024;
}
table query_ipv6_dstAddr_miss {
    reads { camus_meta.state: exact; }
    actions { set_next_state; }
    size: 1024;
}

table query_stful_color_exact {
    reads { camus_meta.state: exact; stful.color: exact; }
    actions { set_next_state; }
    size: 1024;
}
table query_stful_color_miss {
    reads { camus_meta.state: exact; }
    actions { set_next_state; }
    size: 1024;
}

meter meter1 {
    type: bytes;
    direct: query_ipv6_dstAddr_lpm;
    result: stful.color;
}

control ingress {
    if (valid(ipv6)) {
        apply(query_ipv6_dstAddr_lpm) {
            miss {
                apply(query_ipv6_dstAddr_miss);
            }
        }

        apply(query_stful_color_exact) {
            miss {
                apply(query_stful_color_miss);
            }
        }

        apply(query_actions);
    }
}
