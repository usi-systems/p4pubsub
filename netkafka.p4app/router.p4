#include "header.p4"
#include "parser.p4"

metadata intrinsic_metadata_t intrinsic_metadata;
metadata bs_meta_t bs_meta;

action dont_prune() {
    modify_field(bs_meta.dont_prune, 1);
}

action _drop() {
    drop();
}

action _nop() {
}

action set_nhop(nhop_ipv4, port) {
    modify_field(ipv4.dstAddr, nhop_ipv4);
    modify_field(standard_metadata.egress_spec, port);
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
    modify_field(udp.checksum, 0);
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

action set_mgid0(mgid) {
    modify_field(intrinsic_metadata.mcast_grp, mgid, mgid);
}

action set_mgid1(mgid) {
    modify_field(intrinsic_metadata.mcast_grp, mgid, mgid);
}

action set_mgid2(mgid) {
    modify_field(intrinsic_metadata.mcast_grp, mgid, mgid);
}

action set_mgid3(mgid) {
    modify_field(intrinsic_metadata.mcast_grp, mgid, mgid);
}

action set_mgid4(mgid) {
    modify_field(intrinsic_metadata.mcast_grp, mgid, mgid);
}

action set_mgid5(mgid) {
    modify_field(intrinsic_metadata.mcast_grp, mgid, mgid);
}

action set_mgid6(mgid) {
    modify_field(intrinsic_metadata.mcast_grp, mgid, mgid);
}

action set_mgid7(mgid) {
    modify_field(intrinsic_metadata.mcast_grp, mgid, mgid);
}

table mg_ternary0 {
    reads {
        tag.tag0: ternary;
    }
    actions {
        _nop;
        set_mgid0;
        _drop;
    }
    size: 512;
}

table mg_ternary1 {
    reads {
        tag.tag1: ternary;
    }
    actions {
        _nop;
        set_mgid1;
        _drop;
    }
    size: 512;
}

table mg_ternary2 {
    reads {
        tag.tag2: ternary;
    }
    actions {
        _nop;
        set_mgid2;
        _drop;
    }
    size: 512;
}

table mg_ternary3 {
    reads {
        tag.tag3: ternary;
    }
    actions {
        _nop;
        set_mgid3;
        _drop;
    }
    size: 512;
}

table mg_ternary4 {
    reads {
        tag.tag4: ternary;
    }
    actions {
        _nop;
        set_mgid4;
        _drop;
    }
    size: 512;
}

table mg_ternary5 {
    reads {
        tag.tag5: ternary;
    }
    actions {
        _nop;
        set_mgid5;
        _drop;
    }
    size: 512;
}

table mg_ternary6 {
    reads {
        tag.tag6: ternary;
    }
    actions {
        _nop;
        set_mgid6;
        _drop;
    }
    size: 512;
}

table mg_ternary7 {
    reads {
        tag.tag7: ternary;
    }
    actions {
        _nop;
        set_mgid7;
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

table egress_prune0 {
    reads {
        standard_metadata.egress_port: exact;
        tag.tag0: ternary;
    }
    actions {
        _nop;
        dont_prune;
    }
    size: 256;
}

table egress_prune1 {
    reads {
        standard_metadata.egress_port: exact;
        tag.tag1: ternary;
    }
    actions {
        _nop;
        dont_prune;
    }
    size: 256;
}

table egress_prune2 {
    reads {
        standard_metadata.egress_port: exact;
        tag.tag2: ternary;
    }
    actions {
        _nop;
        dont_prune;
    }
    size: 256;
}

table egress_prune3 {
    reads {
        standard_metadata.egress_port: exact;
        tag.tag3: ternary;
    }
    actions {
        _nop;
        dont_prune;
    }
    size: 256;
}

table egress_prune4 {
    reads {
        standard_metadata.egress_port: exact;
        tag.tag4: ternary;
    }
    actions {
        _nop;
        dont_prune;
    }
    size: 256;
}

table egress_prune5 {
    reads {
        standard_metadata.egress_port: exact;
        tag.tag5: ternary;
    }
    actions {
        _nop;
        dont_prune;
    }
    size: 256;
}

table egress_prune6 {
    reads {
        standard_metadata.egress_port: exact;
        tag.tag6: ternary;
    }
    actions {
        _nop;
        dont_prune;
    }
    size: 256;
}

table egress_prune7 {
    reads {
        standard_metadata.egress_port: exact;
        tag.tag7: ternary;
    }
    actions {
        _nop;
        dont_prune;
    }
    size: 256;
}

table check_prune {
    reads {
        bs_meta.dont_prune: exact;
    }
    actions {
        _nop;
        _drop;
    }
    size: 2;
}

control ingress {
    if(valid(ipv4)) {
        if (valid(tag)) {
            apply(mg_ternary0);
            apply(mg_ternary1);
            apply(mg_ternary2);
            apply(mg_ternary3);
            apply(mg_ternary4);
            apply(mg_ternary5);
            apply(mg_ternary6);
            apply(mg_ternary7);
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
            apply(egress_prune0);
            apply(egress_prune1);
            apply(egress_prune2);
            apply(egress_prune3);
            apply(egress_prune4);
            apply(egress_prune5);
            apply(egress_prune6);
            apply(egress_prune7);
            apply(check_prune);
        }
        apply(send_frame);
    }
}

