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
        seq: 64;
        msg_cnt: 16;
    }
}

header_type moldudp_msg_t {
    fields {
        msg_len: 16;
    }
}

#define ITCH41_MSG_ADD_ORDER       65 // A

header_type itch_msg_type_t {
    fields {
        msg_type: 8;
    }
}

header_type itch_add_order_t {
    fields {
        stock_locate: 16;
        tracking_number: 16;
        timestamp_ns: 48;
        order_ref_number: 64;
        buy_sell_indicator: 8;
        shares: 32;
        stock: 64;
        price: 32;
    }
}

@pragma query_field(add_order.buy_sell_indicator)
@pragma query_field(add_order.price)
@pragma query_field(add_order.shares)
@pragma query_field_exact(add_order.stock)

header itch_add_order_t add_order;

#endif // __HEADER_P4__
