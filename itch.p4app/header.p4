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

header_type moldudp_hdr_t {
    fields {
        session: 80;
        seq: 32;
        msg_cnt: 16;
    }
}

header_type moldudp_msg_t {
    fields {
        msg_len: 16;
    }
}

#define ITCH41_MSG_STOCK_DIRECTORY 82 // R

header_type itch_msg_type_t {
    fields {
        msg_type: 8;
    }
}

header_type itch_stock_directory_t {
    fields {
        timestamp_ns: 32;
        stock: 64;
        market_category: 8;
        financial_status_indicator: 8;
        round_lot_size: 32;
        round_lots_only: 8;
    }
}

header_type intrinsic_metadata_t {
    fields {
        mcast_grp : 4;
        egress_rid : 4;
        mcast_hash : 16;
        lf_field_list: 32;
        ingress_global_timestamp : 64;
        resubmit_flag : 16;
        recirculate_flag : 16;
    }
}

#endif // __HEADER_P4__
