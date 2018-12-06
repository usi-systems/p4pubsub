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
        // XXX We ignore these 12 MSB because the TCAM can only do a range
        // match on the first 20 bits
        hop_latency_msb: 12;
        hop_latency: 20;
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

header_type camus_meta_t {
    fields {
        state: 16;
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

metadata camus_meta_t camus_meta;

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

table query_int_hop_latency_hop_latency_exact {
    reads { camus_meta.state: exact; int_hop_latency.hop_latency: exact; }
    actions { set_next_state; }
    size: 1024;
}
table query_int_hop_latency_hop_latency_range {
    reads { camus_meta.state: exact; int_hop_latency.hop_latency: range; }
    actions { set_next_state; }
    size: 1024;
}
table query_int_hop_latency_hop_latency_miss {
    reads { camus_meta.state: exact; }
    actions { set_next_state; }
    size: 1024;
}

table query_int_switch_id_switch_id_exact {
    reads { camus_meta.state: exact; int_switch_id.switch_id: exact; }
    actions { set_next_state; }
    size: 1024;
}
table query_int_switch_id_switch_id_range {
    reads { camus_meta.state: exact; int_switch_id.switch_id: range; }
    actions { set_next_state; }
    size: 1024;
}
table query_int_switch_id_switch_id_miss {
    reads { camus_meta.state: exact; }
    actions { set_next_state; }
    size: 1024;
}

control ingress {
    if (valid(int_header)) {
        apply(query_int_switch_id_switch_id_exact) {
            miss {
                apply(query_int_switch_id_switch_id_miss);
            }
        }

        apply(query_int_hop_latency_hop_latency_range) {
            miss {
                apply(query_int_hop_latency_hop_latency_exact) {
                    miss {
                        apply(query_int_hop_latency_hop_latency_miss);
                    }
                }
            }
        }

        apply(query_actions);
  }
}


// *********************************
//            EGRESS
// *********************************

