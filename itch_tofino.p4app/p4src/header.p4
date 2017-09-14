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


header_type intrinsic_metadata_t {
    fields {
        resubmit_flag : 1;              // flag distinguishing original packets
                                        // from resubmitted packets.

        ingress_global_timestamp : 48;     // global timestamp (ns) taken upon
                                        // arrival at ingress.

        mcast_grp : 16;                 // multicast group id (key for the
                                        // mcast replication table)

        deflection_flag : 1;            // flag indicating whether a packet is
                                        // deflected due to deflect_on_drop.
        deflect_on_drop : 1;            // flag indicating whether a packet can
                                        // be deflected by TM on congestion drop

        enq_congest_stat : 2;           // queue congestion status at the packet
                                        // enqueue time.

        deq_congest_stat : 2;           // queue congestion status at the packet
                                        // dequeue time.

        mcast_hash : 13;                // multicast hashing

        egress_rid : 16;                // Replication ID for multicast

        lf_field_list : 32;             // Learn filter field list

        priority : 3;                   // set packet priority

        ingress_cos: 3;                 // ingress cos

        packet_color: 2;                // packet color

        qid: 5;                         // queue id
    }
}

#endif // __HEADER_P4__
