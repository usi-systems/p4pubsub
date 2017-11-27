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
    modify_field(intrinsic_metadata.mcast_grp, mgid);
}
table bcast_to_egress {
    actions { set_mgid; }
    size: 1;
}


table drop_ingr {
    actions { _drop; _nop; }
    size: 1;
}

control ingress {
    if (valid(label)) {
        if (label.msg_type == MSG_TYPE_DATA) {
            apply(bcast_to_egress);
        }

        apply(drop_ingr);
    }

    if (valid(ipv4)) {
        if (intrinsic_metadata.mcast_grp == 0 and
                standard_metadata.egress_spec == 0) {
            apply(ipv4_lpm);
        }
        apply(forward);
    }
}


//
// EGRESS
//

header_type seq_metadata_t {
    fields {
        global_seq: 32;
        expect_global_seq: 32;
        dont_prune: 1;
        was_pruned: 1;
    }
}
metadata seq_metadata_t md;

register global_seq_reg {
  width: 32;
  instance_count: 1;
}

#define NUM_PORTS 64
register port_seq_reg {
  width: 32;
  instance_count: NUM_PORTS;
}

action do_prune() {
    drop();
    modify_field(md.was_pruned, 1);
}


table label_prune {
    reads {
        standard_metadata.egress_port: exact;
        label.topic: exact;
    }
    actions {
        _nop;
        do_prune;
    }
    default_action: do_prune;
    size: 1024;
}

action inc_seq() {
    register_read(label.port_seq, port_seq_reg, standard_metadata.egress_port);
    add_to_field(label.port_seq, 1);
    register_write(port_seq_reg, standard_metadata.egress_port, label.port_seq);
    modify_field(udp.checksum, 0);
}
table seq {
    actions { inc_seq; }
    default_action: inc_seq;
    size: 1;
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

table drop_egr {
    actions { _drop; _nop; }
    size: 1;
}

action do_load_global_seq() {
    register_read(md.global_seq, global_seq_reg, 0);
    register_read(md.expect_global_seq, global_seq_reg, 0);
    add_to_field(md.expect_global_seq, 1);
}
table load_global_seq {
    actions { do_load_global_seq; }
    default_action: do_load_global_seq;
    size: 1;
}

action do_update_global_seq() {
    add_to_field(md.global_seq, 1);
    register_write(global_seq_reg, 0, md.global_seq);
}
table update_global_seq {
    actions { do_update_global_seq; }
    default_action: do_update_global_seq;
    size: 1;
}

action do_wrong_global_seq() {
    modify_field(label.msg_type, MSG_TYPE_MISSING);
    modify_field(label.global_seq2, md.expect_global_seq);
    modify_field(md.dont_prune, 1);
}
table wrong_global_seq {
    actions { do_wrong_global_seq; }
    default_action: do_wrong_global_seq;
    size: 1;
}

control egress {
    if (valid(label)) {
        if (label.msg_type == MSG_TYPE_DATA) {

            apply(load_global_seq);

            if (label.global_seq > md.expect_global_seq) {
                apply(wrong_global_seq);
            }
            else if (label.global_seq == md.expect_global_seq) {
                apply(update_global_seq);
            }

            if (md.dont_prune == 0)
                apply(label_prune);

            if (md.was_pruned == 0) {
                apply(seq);
            }

        }

        apply(drop_egr);
    }

    if (valid(ipv4)) {
        apply(send_frame);
    }
}
