#include <tofino/constants.p4>
#include <tofino/intrinsic_metadata.p4>

#define TRACKER_UDP_PORT      1234

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

header_type car_tracker_t {
    fields {
        long: 16;
        lat: 16;
        speed: 16;
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
        TRACKER_UDP_PORT: parse_car_tracker;
        default : ingress;
    }
}


header car_tracker_t car;

parser parse_car_tracker {
    extract(car);
    return ingress;
}


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



table query_car_lat_exact {
    reads { camus_meta.state: exact; car.lat: exact; }
    actions { set_next_state; }
    size: 1024;
}
table query_car_lat_range {
    reads { camus_meta.state: exact; car.lat: range; }
    actions { set_next_state; }
    size: 1024;
}
table query_car_lat_miss {
    reads { camus_meta.state: exact; }
    actions { set_next_state; }
    size: 1024;
}
table query_car_long_exact {
    reads { camus_meta.state: exact; car.long: exact; }
    actions { set_next_state; }
    size: 1024;
}
table query_car_long_range {
    reads { camus_meta.state: exact; car.long: range; }
    actions { set_next_state; }
    size: 1024;
}
table query_car_long_miss {
    reads { camus_meta.state: exact; }
    actions { set_next_state; }
    size: 1024;
}
table query_car_speed_exact {
    reads { camus_meta.state: exact; car.speed: exact; }
    actions { set_next_state; }
    size: 1024;
}
table query_car_speed_range {
    reads { camus_meta.state: exact; car.speed: range; }
    actions { set_next_state; }
    size: 1024;
}
table query_car_speed_miss {
    reads { camus_meta.state: exact; }
    actions { set_next_state; }
    size: 1024;
}
table car_query_actions {
    reads { camus_meta.state: exact; }
    actions { query_drop; set_egress_port; set_mgid; }
    default_action: query_drop;
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
    if (valid(car)) {
        apply(query_car_lat_range) {
            miss {
                apply(query_car_lat_exact) {
                    miss {
                        apply(query_car_lat_miss);
                    }
                }
            }
        }
        apply(query_car_long_range) {
            miss {
                apply(query_car_long_exact) {
                    miss {
                        apply(query_car_long_miss);
                    }
                }
            }
        }
        apply(query_car_speed_range) {
            miss {
                apply(query_car_speed_exact) {
                    miss {
                        apply(query_car_speed_miss);
                    }
                }
            }
        }

        apply(car_query_actions);
    }
    else if (valid(ipv4)) {
        apply(ipv4_lpm) {
            miss {
                apply(dmac);
            }
        }
    }
    else if (valid(ethernet)) {
        apply(dmac);
    }
}

