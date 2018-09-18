header_type query_metadata_t {
  fields {
    state : 16;
  }
}

metadata query_metadata_t query_metadata;

header_type stful_meta_t {
  fields {
    
  }
}

metadata stful_meta_t stful_meta;

action set_next_state(next_state) {
  modify_field(query_metadata.state, next_state);
}

action set_mgid(mgid) {
  modify_field(intrinsic_metadata.mcast_grp, mgid);
}

action set_egress_port(port) {
  modify_field(standard_metadata.egress_spec, port);
}

action query_drop() {
  drop();
}

header_type intrinsic_metadata_t {
  fields {
    mcast_grp : 4;
    egress_rid : 4;
    mcast_hash : 16;
    lf_field_list : 32;
    ingress_global_timestamp : 64;
    resubmit_flag : 16;
    recirculate_flag : 16;
  }
}

header_type ethernet_t {
  fields {
    dstAddr : 48;
    srcAddr : 48;
    etherType : 16;
  }
}

header_type arp_ipv4_t {
  fields {
    sha : 48;
    spa : 32;
    tha : 48;
    tpa : 32;
  }
}

header_type arp_ipv4_metadata_t {
  fields {
    sha : 48;
    spa : 32;
    tha : 48;
    tpa : 32;
  }
}

header_type arp_t {
  fields {
    htype : 16;
    ptype : 16;
    hlen : 8;
    plen : 8;
    oper : 16;
  }
}

header_type routing_metadata_t {
  fields {
    nhop_ipv4 : 32;
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
    dstAddr : 32;
  }
}

header_type udp_t {
  fields {
    srcPort : 16;
    dstPort : 16;
    length_ : 16;
    checksum : 16;
  }
}

header_type moldudp_hdr_t {
  fields {
    session : 80;
    seq : 64;
    msg_cnt : 16;
  }
}

header_type moldudp_msg_t {
  fields {
    msg_len : 16;
  }
}

header_type itch_msg_type_t {
  fields {
    msg_type : 8;
  }
}

header_type itch_add_order_t {
  fields {
    stock_locate : 16;
    tracking_number : 16;
    timestamp_ns : 48;
    order_ref_number : 64;
    buy_sell_indicator : 8;
    shares : 32;
    stock : 64;
    price : 32;
  }
}

@pragma query_field(add_order.buy_sell_indicator)

@pragma query_field(add_order.price)

@pragma query_field(add_order.shares)

@pragma query_field_exact(add_order.stock)

header itch_add_order_t add_order;

metadata routing_metadata_t routing_metadata;

metadata arp_ipv4_metadata_t arp_ipv4_meta;

metadata intrinsic_metadata_t intrinsic_metadata;

parser start {
  return parse_ethernet;
}

header ethernet_t ethernet;

parser parse_ethernet {
  extract(ethernet);
  return select (latest.etherType) {
    2048 : parse_ipv4;
    2054 : parse_arp;
    default : ingress;
  }
}

header arp_t arp;

header arp_ipv4_t arp_ipv4;

parser parse_arp {
  extract(arp);
  return select (latest.ptype) {
    2048 : parse_arp_ipv4;
    default : ingress;
  }
}

parser parse_arp_ipv4 {
  extract(arp_ipv4);
  return ingress;
}

header ipv4_t ipv4;

field_list ipv4_checksum_list {
  ipv4.version;
  ipv4.ihl;
  ipv4.diffserv;
  ipv4.totalLen;
  ipv4.identification;
  ipv4.flags;
  ipv4.fragOffset;
  ipv4.ttl;
  ipv4.protocol;
  ipv4.srcAddr;
  ipv4.dstAddr;
}

field_list_calculation ipv4_checksum {
  input {
    ipv4_checksum_list;
  }
  algorithm : csum16;
  output_width : 16;
}

calculated_field ipv4.hdrChecksum {
  verify ipv4_checksum;
  update ipv4_checksum;
}

parser parse_ipv4 {
  extract(ipv4);
  return select (ipv4.protocol) {
    17 : parse_udp;
    default : ingress;
  }
}

header udp_t udp;

parser parse_udp {
  extract(udp);
  return select (udp.dstPort) {
    1234 : parse_moldudp;
    default : ingress;
  }
}

header moldudp_hdr_t moldudp_hdr;

header moldudp_msg_t moldudp_msg;

header itch_msg_type_t itch_msg_type;

parser parse_moldudp {
  extract(moldudp_hdr);
  extract(moldudp_msg);
  extract(itch_msg_type);
  return select (itch_msg_type.msg_type) {
    65 : parse_add_order;
    default : ingress;
  }
}

parser parse_add_order {
  extract(add_order);
  return ingress;
}

action _drop() {
  drop();
}

action _nop() {
  
}

action set_nhop(nhop_ipv4, 
  port) {
  modify_field(routing_metadata.nhop_ipv4, nhop_ipv4);
  modify_field(standard_metadata.egress_spec, port);
  modify_field(ipv4.ttl, (ipv4.ttl - 1));
}

table ipv4_lpm {
  reads {
    ipv4.dstAddr : lpm;
  }
  actions {
    set_nhop;
    _drop;
  }
  size : 1024;
}

action set_dmac(dmac) {
  modify_field(ethernet.dstAddr, dmac);
  modify_field(udp.checksum, 0);
}

table forward {
  reads {
    standard_metadata.egress_port : exact;
  }
  actions {
    set_dmac;
    _drop;
  }
  size : 512;
}

action set_dip(dip) {
  modify_field(ipv4.dstAddr, dip);
}

table icn_to_ip {
  reads {
    standard_metadata.egress_port : exact;
  }
  actions {
    set_dip;
    _drop;
  }
  size : 512;
}

action rewrite_mac(smac) {
  modify_field(ethernet.srcAddr, smac);
}

table send_frame {
  reads {
    standard_metadata.egress_port : exact;
  }
  actions {
    rewrite_mac;
    _drop;
  }
  size : 256;
}

table handle_arp {
  reads {
    arp_ipv4.tpa : lpm;
    arp.oper : exact;
  }
  actions {
    forward_arp;
  }
  default_action: reply_arp;
  size : 256;
}

action forward_arp(port) {
  modify_field(standard_metadata.egress_spec, port);
}

action reply_arp() {
  modify_field(arp_ipv4_meta.tha, arp_ipv4.tha);
  modify_field(arp_ipv4_meta.sha, arp_ipv4.sha);
  modify_field(arp_ipv4_meta.spa, arp_ipv4.spa);
  modify_field(arp_ipv4_meta.tpa, arp_ipv4.tpa);
  modify_field(arp_ipv4.tha, arp_ipv4_meta.sha);
  modify_field(arp_ipv4.sha, arp_ipv4_meta.tha);
  modify_field(arp_ipv4.spa, arp_ipv4_meta.tpa);
  modify_field(arp_ipv4.tpa, arp_ipv4_meta.spa);
  modify_field(arp.oper, 2);
  modify_field(standard_metadata.egress_spec, standard_metadata.ingress_port);
}

table just_drop {
  actions {
    _drop;
    }
    default_action: _drop;
    size : 256;
  }

control ingress {
  if (valid(ipv4)) {
    if (valid(add_order)) {
      apply(query_add_order_buy_sell_indicator_exact) {
        miss {
          apply(query_add_order_buy_sell_indicator_range) {
            miss {
              apply(query_add_order_buy_sell_indicator_miss);
            }
          }
        }
      }
      apply(query_add_order_price_exact) {
        miss {
          apply(query_add_order_price_range) {
            miss {
              apply(query_add_order_price_miss);
            }
          }
        }
      }
      apply(query_add_order_shares_exact) {
        miss {
          apply(query_add_order_shares_range) {
            miss {
              apply(query_add_order_shares_miss);
            }
          }
        }
      }
      apply(query_add_order_stock_exact) {
        miss {
          apply(query_add_order_stock_miss);
        }
      }
      apply(query_actions);
    }
    if (((intrinsic_metadata.mcast_grp == 0) and (standard_metadata.egress_spec == 
                                                0))) {
      apply(ipv4_lpm);
    }
  }
  if (valid(arp)) {
    apply(handle_arp);
  }
}

control egress {
  if (valid(ipv4)) {
    apply(icn_to_ip);
    apply(send_frame);
    apply(forward);
  }
  if (valid(arp)) {
    
  } else {
    if ((standard_metadata.egress_port == standard_metadata.ingress_port)) {
      apply(just_drop);
    }
  }
}

table query_add_order_stock_exact {
  reads {
    query_metadata.state : exact;
    add_order.stock : exact;
  }
  actions {
    set_next_state;
  }
}

table query_add_order_stock_miss {
  reads {
    query_metadata.state : exact;
  }
  actions {
    set_next_state;
  }
}

table query_add_order_shares_range {
  reads {
    query_metadata.state : exact;
    add_order.shares : range;
  }
  actions {
    set_next_state;
  }
}

table query_add_order_shares_exact {
  reads {
    query_metadata.state : exact;
    add_order.shares : exact;
  }
  actions {
    set_next_state;
  }
}

table query_add_order_shares_miss {
  reads {
    query_metadata.state : exact;
  }
  actions {
    set_next_state;
  }
}

table query_add_order_price_range {
  reads {
    query_metadata.state : exact;
    add_order.price : range;
  }
  actions {
    set_next_state;
  }
}

table query_add_order_price_exact {
  reads {
    query_metadata.state : exact;
    add_order.price : exact;
  }
  actions {
    set_next_state;
  }
}

table query_add_order_price_miss {
  reads {
    query_metadata.state : exact;
  }
  actions {
    set_next_state;
  }
}

table query_add_order_buy_sell_indicator_range {
  reads {
    query_metadata.state : exact;
    add_order.buy_sell_indicator : range;
  }
  actions {
    set_next_state;
  }
}

table query_add_order_buy_sell_indicator_exact {
  reads {
    query_metadata.state : exact;
    add_order.buy_sell_indicator : exact;
  }
  actions {
    set_next_state;
  }
}

table query_add_order_buy_sell_indicator_miss {
  reads {
    query_metadata.state : exact;
  }
  actions {
    set_next_state;
  }
}

table query_actions {
  reads {
    query_metadata.state : exact;
  }
  actions {
    set_mgid;
    set_egress_port;
    query_drop;
  }
}
