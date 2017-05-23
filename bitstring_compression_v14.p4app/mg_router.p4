#include "header.p4"
#include "parser.p4"

metadata intrinsic_metadata_t intrinsic_metadata;

action _drop() {
    drop();
}

action _nop() {
}

action set_nhop(nhop_ipv4, port) {
    modify_field(ipv4.dstAddr, nhop_ipv4);
    modify_field(standard_metadata.egress_spec, port);
    modify_field(ipv4.ttl, ipv4.ttl - 1);
}

table ipv4_lpm {
    reads {
        ipv4.dstAddr : lpm;
    }
    actions {
        set_nhop;
        _drop;
    }
    size: 1024;
}

action set_dmac(dmac) {
    modify_field(ethernet.dstAddr, dmac);
}

table forward {
    reads {
        ipv4.dstAddr: exact;
    }
    actions {
        set_dmac;
        _drop;
    }
    size: 512;
}

action set_mgid(mgid) {
    intrinsic_metadata.mcast_grp = mgid;
    udp.checksum = 0;
}

table mg_ternary {
    reads {
        tag.tag: ternary;
    }
    actions {
        _nop;
        set_mgid;
        _drop;
    }
    size: 512;
}

action rewrite_mac(smac) {
    modify_field(ethernet.srcAddr, smac);
}

table send_frame {
    reads {
        standard_metadata.egress_port: exact;
    }
    actions {
        rewrite_mac;
        _drop;
    }
    size: 256;
}

table egress_prune {
    reads {
        standard_metadata.egress_port: exact;
        tag.tag: ternary;
    }
    actions {
        _nop;
        _drop;
    }
    size: 256;
}

control ingress {
    if(valid(ipv4) and ipv4.ttl > 0) {
        if (valid(tag)) {
            apply(mg_ternary);
        }

        if (intrinsic_metadata.mcast_grp == 0) {
            apply(ipv4_lpm);
        }

        apply(forward);
    }
}

control egress {
    if (valid(ipv4)) {
        if (valid(tag)) {
            apply(egress_prune);
        }
        apply(send_frame);
    }
}

