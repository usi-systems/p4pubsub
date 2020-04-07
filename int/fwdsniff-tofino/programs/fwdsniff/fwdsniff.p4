#include <tofino/constants.p4>
#include <tofino/intrinsic_metadata.p4>

parser start { return ingress; }

action set_mgid(mgid) { modify_field(ig_intr_md_for_tm.mcast_grp_a, mgid); }
action set_egr(port) { modify_field(ig_intr_md_for_tm.ucast_egress_port, port); }

table fwd {
    reads { ig_intr_md.ingress_port: exact; }
    actions { set_egr; set_mgid; }
    size: 1024;
}

control ingress {
    apply(fwd);
}
