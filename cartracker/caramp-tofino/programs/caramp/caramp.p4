#include <tofino/constants.p4>
#include <tofino/intrinsic_metadata.p4>

#define TRACKER_UDP_PORT      1234

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
        lat: 16;
        long: 16;
        speed: 16;
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


// *********************************
//            INGRESS
// *********************************

action nop() { }

action _drop() { drop(); }

action set_mgid(mgid) {
    modify_field(ig_intr_md_for_tm.mcast_grp_a, mgid);
}

action set_egress_port(port) {
    modify_field(ig_intr_md_for_tm.ucast_egress_port, port);
}

table forward {
    reads {
        car.lat: exact;
    }
    actions {
        set_mgid;
        set_egress_port;
        _drop;
    }
}

control ingress {
    if (valid(car))
        apply(forward);
}


// *********************************
//            EGRESS
// *********************************

action decr_car_fields() {
    subtract_from_field(car.speed, 1);
}

action set_car_fields(speed, lat, long) {
    modify_field(car.speed, speed);
    modify_field(car.lat, lat);
    modify_field(car.long, long);
}

table update_car_fields {
    reads {
        ig_intr_md.ingress_port: ternary;
        car.lat: range;
    }
    actions {
        decr_car_fields;
        set_car_fields;
        nop;
    }
    size: 64;
}


action decr_lat() { subtract_from_field(car.lat, 1); }
table update_lat { actions { decr_lat; } default_action: decr_lat; }

action set_dst(mac, ip) {
    modify_field(ethernet.dstAddr, mac);
    modify_field(ipv4.dstAddr, ip);
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

action disable_udp_checksum() { modify_field(udp.checksum, 0); }
table udp_checksum { actions { disable_udp_checksum; } default_action: disable_udp_checksum; size: 1; }


control egress {
    if (valid(ipv4))
        apply(rewrite_dst);

    if (valid(car)) {
        apply(update_lat);
        apply(update_car_fields);
        apply(udp_checksum);
    }
}
