#include <core.p4>
#include <v1model.p4>

#include "header.p4"
#include "parser.p4"

control egress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    action rewrite_mac(bit<48> smac) {
        hdr.ethernet.srcAddr = smac;
    }
    action _drop() {
        mark_to_drop();
    }
    table send_frame {
        actions = {
            rewrite_mac;
            _drop;
            NoAction;
        }
        key = {
            standard_metadata.egress_port: exact;
        }
        size = 256;
        default_action = NoAction();
    }
    apply {
        if (hdr.ipv4.isValid()) {
          send_frame.apply();
        }
    }
}

control ingress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    action _drop() {
        mark_to_drop();
    }
    action set_nhop(bit<32> nhop_ipv4) {
        hdr.ipv4.dstAddr = nhop_ipv4;
        hdr.udp.checksum = (bit<16>)0;
    }
    table ipv4_port {
        actions = {
            set_nhop;
            NoAction;
        }
        key = {
            standard_metadata.egress_spec: exact;
        }
        size = 1024;
        default_action = NoAction();
    }
    action set_dmac(bit<48> dmac) {
        hdr.ethernet.dstAddr = dmac;
    }
    table forward {
        actions = {
            set_dmac;
            _drop;
            NoAction;
        }
        key = {
            standard_metadata.egress_spec: exact;
        }
        size = 512;
        default_action = NoAction();
    }
    action set_port(bit<9> port) {
        standard_metadata.egress_spec = port;
    }
    action set_port_lbl() {
        standard_metadata.egress_spec = hdr.label.landmark_port;
    }
    table label {
        actions = {
            _drop;
            set_port;
            set_port_lbl;
            NoAction;
        }
        key = {
            hdr.label.dst: ternary;
            hdr.label.landmark: ternary;
        }
        size = 1024;
        default_action = NoAction();
    }
    apply {
        if (hdr.ipv4.isValid()) {
          if (hdr.label.isValid()) {
            label.apply();
          }
          ipv4_port.apply();
          forward.apply();
        }
    }
}

V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(), DeparserImpl()) main;
