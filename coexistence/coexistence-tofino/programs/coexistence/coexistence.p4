#include <tofino/constants.p4>
#include <tofino/intrinsic_metadata.p4>

#define ENABLE_CAMUS_IPV4     0

#define ITCH_UDP_PORT         1234
#define INT_UDP_PORT          1337
#define DNS_UDP_PORT          53

#define MAC_TABLE_SIZE        1024
#define IPV4_TABLE_SIZE       1024

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

header_type mold_t {
    fields {
        session: 80;
        seqnum: 64;
        count_0: 8;
        count: 8;
    }
}

header_type add_order_t {
    fields {
        len: 16;
        typecode: 8;
        locate: 16;
        track_num: 16;
        timestamp: 48;
        ref: 64;
        buy_sell:8;
        shares:32;
        ticker1:32;
        ticker2:32;
        // XXX We ignore these 12 MSB because the TCAM can only do a range
        // match on the first 20 bits
        price_extra:12;
        price:20;
    }
}

header_type dns_header_t {
    fields {
        trans_id: 16;
        is_res: 1;
        op_code: 4;
        authoritative: 1;
        truncated: 1;
        rec_desired: 1;
        rec_available: 1;
        reserved: 1;
        authenticated: 1;
        not_authenticated: 1;
        reply_code: 4;
        num_questions: 16;
        num_answers: 16;
        num_authorities: 16;
        num_additional: 16;
    }
}

header_type dns_query_t {
    fields {
        len: 8;
        // XXX: labels (hostnames) must be exactly 4 chars
        label: 32;
        term: 8;
        type_: 16;
        class: 16;
    }
}

header_type dns_answer_t {
    fields {
        name: 16;
        type_: 16;
        class: 16;
        ttl: 32;
        len: 16;
        data: 32;
    }
}

header_type ingr_meta_t {
    fields {
        tmp_mac: 48;
        tmp_ip: 32;
        tmp_port: 16;
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
        ITCH_UDP_PORT: parse_itch;
        DNS_UDP_PORT: parse_dns;
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

header mold_t mold;
header add_order_t add_order;

parser parse_itch {
    extract(mold);
    extract(add_order);
    return ingress;
}


header dns_header_t dns_header;
header dns_query_t dns_query;
header dns_answer_t dns_answer;

parser parse_dns {
    extract(dns_header);
    extract(dns_query);
    return select(dns_header.num_answers) {
        0: ingress;
        default: parse_dns_answer;
    }
}

parser parse_dns_answer {
    extract(dns_answer);
    return ingress;
}

metadata ingr_meta_t ingr_meta;

metadata camus_meta_t camus_meta;


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

action rev_udp() {
    modify_field(ig_intr_md_for_tm.ucast_egress_port, ig_intr_md.ingress_port);

    swap(ethernet.dstAddr, ethernet.srcAddr);
    swap(ipv4.dstAddr, ipv4.srcAddr);
    swap(udp.dstPort, udp.srcPort);

    modify_field(udp.checksum, 0);
}

action answerDNS(ip) {
    rev_udp();
    modify_field(dns_header.is_res, 1);
    modify_field(dns_header.op_code, 0);
    modify_field(dns_header.authoritative, 0);
    modify_field(dns_header.truncated, 0);
    modify_field(dns_header.rec_desired, 1);
    modify_field(dns_header.rec_available, 1);
    modify_field(dns_header.reserved, 0);
    modify_field(dns_header.authenticated, 0);
    modify_field(dns_header.not_authenticated, 0);
    modify_field(dns_header.reply_code, 0); // No error

    modify_field(dns_header.num_answers, 1);

    add_header(dns_answer);
    modify_field(dns_answer.name, 0xc00c);
    modify_field(dns_answer.type_, 1);
    modify_field(dns_answer.class, 1);
    modify_field(dns_answer.ttl, 233);
    modify_field(dns_answer.len, 4);
    modify_field(dns_answer.data, ip);

    add_to_field(udp.length_, 16);
    add_to_field(ipv4.totalLen, 16);
}

action notfoundDNS() {
    rev_udp();
    modify_field(dns_header.is_res, 1);
    modify_field(dns_header.op_code, 0);
    modify_field(dns_header.reply_code, 3); // No such name
}


table query_int_switch_id_switch_id_exact {
    reads { camus_meta.state: exact; int_switch_id.switch_id: exact; }
    actions { set_next_state; }
    size: 1024;
}
table query_int_switch_id_switch_id_miss {
    reads { camus_meta.state: exact; }
    actions { set_next_state; }
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
table int_query_actions {
    reads { camus_meta.state: exact; }
    actions { query_drop; set_egress_port; set_mgid; }
    default_action: query_drop;
    size: 1024;
}


table query_add_order_shares_exact {
    reads { camus_meta.state: exact; add_order.shares: exact; }
    actions { set_next_state; }
    size: 1024;
}
table query_add_order_shares_miss {
    reads { camus_meta.state: exact; }
    actions { set_next_state; }
    size: 1024;
}
table query_add_order_price_exact {
    reads { camus_meta.state: exact; add_order.price: exact; }
    actions { set_next_state; }
    size: 1024;
}
table query_add_order_price_range {
    reads { camus_meta.state: exact; add_order.price: range; }
    actions { set_next_state; }
    size: 1024;
}
table query_add_order_price_miss {
    reads { camus_meta.state: exact; }
    actions { set_next_state; }
    size: 1024;
}
table itch_query_actions {
    reads { camus_meta.state: exact; }
    actions { query_drop; set_egress_port; set_mgid; }
    default_action: query_drop;
    size: 1024;
}

table query_ipv4_dstAddr_exact {
    reads { camus_meta.state: exact; ipv4.dstAddr: exact; }
    actions { set_next_state; }
    size: 1024;
}
table query_ipv4_dstAddr_miss {
    reads { camus_meta.state: exact; }
    actions { set_next_state; }
    size: 1024;
}
table ipv4_query_actions {
    reads { camus_meta.state: exact; }
    actions { query_drop; set_egress_port; set_mgid; }
    default_action: query_drop;
    size: 1024;
}

table query_dns_query_label_exact {
    reads { camus_meta.state: exact; dns_query.label: exact; }
    actions { set_next_state; }
    size: 1024;
}
table query_dns_query_label_miss {
    reads { camus_meta.state: exact; }
    actions { set_next_state; }
    size: 1024;
}
table dns_query_actions {
    reads { camus_meta.state: exact; }
    actions { notfoundDNS; answerDNS; }
    default_action: notfoundDNS;
    size: 1024;
}

table dmac {
    reads { ethernet.dstAddr: exact; }
    actions { set_egress_port; }
    size: MAC_TABLE_SIZE;
}

table ipv4_lpm {
    reads { ipv4.dstAddr: lpm; }
    actions { set_egress_port; }
    size: IPV4_TABLE_SIZE;
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

        apply(int_query_actions);
    }
    else if (valid(add_order)) {
        apply(query_add_order_shares_exact) {
            miss {
                apply(query_add_order_shares_miss);
            }
        }

        apply(query_add_order_price_exact) {
            miss {
                apply(query_add_order_price_range) {
                    miss {
                        apply(query_add_order_price_miss);
                    }
                }
            }
        }

        apply(itch_query_actions);
    }
    else if (valid(dns_query)) {
        apply(query_dns_query_label_exact) {
            miss {
                apply(query_dns_query_label_miss);
            }
        }

        apply(dns_query_actions);
    }
    else if (valid(ipv4)) {
#if ENABLE_CAMUS_IPV4
        apply(query_ipv4_dstAddr_exact) {
            miss {
                apply(query_ipv4_dstAddr_miss);
            }
        }

        apply(ipv4_query_actions);
#else
        apply(ipv4_lpm) {
            miss {
                apply(dmac);
            }
        }
#endif
    }
    else if (valid(ethernet)) {
        apply(dmac);
    }
}

