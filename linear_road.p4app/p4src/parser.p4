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
        1234: parse_lr;
        default : ingress;
    }
}

header lr_msg_type_t lr_msg_type;
header pos_report_t pos_report;
header accnt_bal_req_t accnt_bal_req;
header toll_notification_t toll_notification;
header accident_alert_t accident_alert;
header accnt_bal_t accnt_bal;

parser parse_lr {
    extract(lr_msg_type);
    return select(lr_msg_type.msg_type) {
        LR_MSG_POS_REPORT: parse_pos_report;
        LR_MSG_ACCNT_BAL_REQ: parse_accnt_bal_req;
        LR_MSG_TOLL_NOTIFICATION: parse_toll_notification;
        LR_MSG_ACCIDENT_ALERT: parse_accident_alert;
        LR_MSG_ACCNT_BAL: parse_accnt_bal;
        default: ingress;
    }
}

parser parse_pos_report {
    extract(pos_report);
    return ingress;
}

parser parse_accnt_bal_req {
    extract(accnt_bal_req);
    return ingress;
}

parser parse_toll_notification {
    extract(toll_notification);
    return ingress;
}

parser parse_accident_alert {
    extract(accident_alert);
    return ingress;
}

parser parse_accnt_bal {
    extract(accnt_bal);
    return ingress;
}

