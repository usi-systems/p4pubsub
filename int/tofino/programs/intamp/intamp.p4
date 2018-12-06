#include <tofino/constants.p4>
#include <tofino/intrinsic_metadata.p4>

#define INT_UDP_PORT 1234

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


header_type udp_t {
    fields {
        srcPort: 16;
        dstPort: 16;
        length_: 16;
        checksum: 16;
    }
}

header_type int_probe_marker_t {
    fields {
        probe_marker1: 32;
        probe_marker2: 32;
    }
}

header_type intl4_shim_t {
    fields {
        int_type: 8;
        rsvd1: 8;
        len: 8;
        dscp: 6;
        rsvd2: 2;
    }
}

header_type int_header_t {
    fields {
        ver: 4;
        rep: 2;
        c: 1;
        e: 1;
        m: 1;
        rsvd1: 7;
        rsvd2: 3;
        hop_metadata_len: 5;
        remaining_hop_cnt: 8;
        instruction_mask_0003: 4;
        instruction_mask_0407: 4;
        instruction_mask_0811: 4;
        instruction_mask_1215: 4;
        rsvd3: 16;
    }
}

header_type int_switch_id_t {
    fields {
        switch_id: 32;
    }
}

header_type int_hop_latency_t {
    fields {
        hop_latency: 32;
    }
}

header_type int_q_occupancy_t {
    fields {
        q_id: 8;
        q_occupancy1: 8;
        q_occupancy2: 8;
        q_occupancy3: 8;
    }
}

// *********************************
//            PARSER
// *********************************

parser start {
    return parse_ethernet;
}

#define ETHERTYPE_IPV4 0x0800

header ethernet_t ethernet;

parser parse_ethernet {
    extract(ethernet);
    return select(latest.etherType) {
        ETHERTYPE_IPV4 : parse_ipv4;
        default: ingress;
    }
}

header ipv4_t ipv4;

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

#define IP_PROT_UDP 0x11

parser parse_ipv4 {
    extract(ipv4);
    return select(ipv4.protocol) {
        IP_PROT_UDP : parse_udp;
        default : ingress;
    }
}

header udp_t udp;

parser parse_udp {
    extract(udp);
    return select(udp.dstPort) {
        INT_UDP_PORT: parse_int;
        default : ingress;
    }
}


header int_probe_marker_t int_probe_marker;
header intl4_shim_t intl4_shim;
header int_header_t int_header;
header int_switch_id_t int_switch_id;
header int_hop_latency_t int_hop_latency;
header int_q_occupancy_t int_q_occupancy;

parser parse_int {
    extract(int_probe_marker);
    extract(intl4_shim);
    extract(int_header);
    extract(int_switch_id);
    extract(int_hop_latency);
    extract(int_q_occupancy);
    return ingress;
}


// *********************************
//            INGRESS
// *********************************

action nop() { }

action set_mgid(mgid) {
    modify_field(ig_intr_md_for_tm.mcast_grp_a, mgid);
}

action set_egress_port(port) {
    modify_field(ig_intr_md_for_tm.ucast_egress_port, port);
}

table forward {
    reads {
        int_header.remaining_hop_cnt: exact;
    }
    actions {
        set_mgid;
        set_egress_port;
    }
}

control ingress {
    if (valid(int_header))
        apply(forward);
}


// *********************************
//            EGRESS
// *********************************

action modify_int() {
    add_to_field(int_switch_id.switch_id, 1);
    add_to_field(int_hop_latency.hop_latency, 1);
    add_to_field(int_q_occupancy.q_occupancy3, 1);
}

table from_loopback {
    reads {
        eg_intr_md.egress_port: exact;
    }
    actions {
        modify_int;
        nop;
    }
    default_action: nop;
}


action decr_hop_cnt() { subtract_from_field(int_header.remaining_hop_cnt, 1); }
table update_hop_cnt { actions { decr_hop_cnt; } default_action: decr_hop_cnt; }

action set_dst(mac, ip) {
    modify_field(ethernet.dstAddr, mac);
    modify_field(ipv4.dstAddr, ip);
    modify_field(udp.checksum, 0);
    modify_field(ipv4.srcAddr, 0x0a00000a);
    modify_field(ethernet.srcAddr, 0x00000000ff);
}

table rewrite_dst {
    reads {
        eg_intr_md.egress_port: exact;
    }
    actions {
        set_dst;
    }
}

control egress {
    if (valid(ipv4))
        apply(rewrite_dst);

    if (valid(int_header)) {
        apply(update_hop_cnt);
        apply(from_loopback);
    }
}
