#include "header.p4"
#include "parser.p4"

action _drop() {
    drop();
}

action _nop() {
}

action set_nhop(nhop_ipv4, port) {
    modify_field(ipv4.dstAddr, nhop_ipv4);
    modify_field(ig_intr_md_for_tm.ucast_egress_port, port);
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



action rewrite_mac(smac) {
    modify_field(ethernet.srcAddr, smac);
}

table send_frame {
    reads {
        eg_intr_md.egress_port: exact;
    }
    actions {
        rewrite_mac;
        _drop;
    }
    size: 256;
}

@pragma query_field(label.topic)
control ingress {
    if(valid(ipv4)) {
        
        if (
           valid(label)
        ) {
           
            @pragma query_control
        }
   

        if (ig_intr_md_for_tm.mcast_grp_a == 0 and
            ig_intr_md_for_tm.ucast_egress_port == 0
        ) {
            apply(ipv4_lpm);
        }

        apply(forward);
    }
}

control egress {
    if (valid(ipv4)) {
        apply(send_frame);
    }
}
