#ifndef __HEADER_P4__
#define __HEADER_P4__ 1

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

#define LR_MSG_POS_REPORT           0
#define LR_MSG_TOLL_NOTIFICATION    10
#define LR_MSG_ACCIDENT_ALERT       11

header_type lr_msg_type_t {
    fields {
        msg_type: 8;
    }
}

header_type pos_report_t {
    fields {
        time: 16;
        vid: 32;
        spd: 8;
        xway: 8;
        lane: 8; // only uses 3 bits
        dir: 8; // only uses 1 bit
        seg: 8;
    }
}

header_type accident_alert_t {
    fields {
        time: 16;
        vid: 32;
        emit: 16;
        seg: 8;
    }
}


#endif // __HEADER_P4__
