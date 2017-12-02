#ifndef __HEADER_P4__
#define __HEADER_P4__ 1

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

#define MSG_TYPE_DATA           1
#define MSG_TYPE_MISSING        2
#define MSG_TYPE_RETRANS_REQ    3

header_type label_t {
    fields {
        msg_type: 8;
        topic: 32;
        timestamp: 64;
    }
}

#endif // __HEADER_P4__
