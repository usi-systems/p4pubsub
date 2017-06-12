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

header_type tag_t {
    fields {
        //tag: 256;
        tag7: 32;
        tag6: 32;
        tag5: 32;
        tag4: 32;
        tag3: 32;
        tag2: 32;
        tag1: 32;
        tag0: 32;
        flag: 8;
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

header_type bs_meta_t {
    fields {
        dont_prune: 1;
    }
}

#endif // __HEADER_P4__
