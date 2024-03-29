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
        1234: parse_moldudp;
        default : ingress;
    }
}

header moldudp_hdr_t moldudp_hdr;
header moldudp_msg_t moldudp_msg;
header itch_msg_type_t itch_msg_type;

parser parse_moldudp {
    extract(moldudp_hdr);
    extract(moldudp_msg);
    extract(itch_msg_type);
    return select(itch_msg_type.msg_type) {
        ITCH41_MSG_ADD_ORDER: parse_add_order;
        default: ingress;
    }
}

header itch_add_order_t add_order;

parser parse_add_order {
    extract(add_order);
    return ingress;
}
