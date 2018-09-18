#define ETHERTYPE_IPV4          0x0800
#define ETHERTYPE_ARP           0x0806
#define IP_PROT_UDP 			0x11

#define ARP_HTYPE_ETHERNET      0x0001
#define ARP_PTYPE_IPV4          0x0800
#define ARP_HLEN_ETHERNET       0x6
#define ARP_PLEN_IPV4           0x4
#define ARP_OPER_REQUEST        0x1
#define ARP_OPER_REPLY          0x2
#define ITCH41_MSG_ADD_ORDER    65 // A

/*
 * Headers
 */

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

header_type ethernet_t {
	fields {
		dstAddr : 48;
		srcAddr : 48;
		etherType : 16;
	}
}

header_type arp_ipv4_t {
  fields{
	sha : 48;
	spa : 32;
	tha : 48;
	tpa : 32;
  }
}

header_type arp_ipv4_metadata_t {
  fields{
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
		seq: 64;
		msg_cnt: 16;
	}
}

header_type moldudp_msg_t {
	fields {
		msg_len: 16;
	}
}

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

@pragma query_field(add_order.buy_sell_indicator)
@pragma query_field(add_order.price)
@pragma query_field(add_order.shares)
@pragma query_field_exact(add_order.stock)

header itch_add_order_t add_order;

metadata routing_metadata_t routing_metadata;
metadata arp_ipv4_metadata_t arp_ipv4_meta;
metadata intrinsic_metadata_t intrinsic_metadata;

/*
 * Parser
 */

parser start {
	return parse_ethernet;
}

#define ETHERTYPE_IPV4 0x0800

header ethernet_t ethernet;

parser parse_ethernet {
	extract(ethernet);
	return select(latest.etherType) {
		ETHERTYPE_IPV4 : parse_ipv4;
		ETHERTYPE_ARP  : parse_arp;
		default: ingress;
	}
}

header arp_t arp;
header arp_ipv4_t arp_ipv4;

parser parse_arp {
  extract(arp);
  return select(latest.ptype) {
	  ETHERTYPE_IPV4 : parse_arp_ipv4; // need to be revised!
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

calculated_field ipv4.hdrChecksum  {
	verify ipv4_checksum;
	update ipv4_checksum;
}

parser parse_ipv4 {
	extract(ipv4);
	return select(ipv4.protocol) {
		IP_PROT_UDP : parse_udp;
		default : ingress;
	}
}

header udp_t udp;

parser parse_udp {
	extract(udp);
	return select(udp.dstPort) {
		1234: parse_moldudp;
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
	return select(itch_msg_type.msg_type) {
		ITCH41_MSG_ADD_ORDER: parse_add_order;
		default: ingress;
	}
}

parser parse_add_order {
	extract(add_order);
	return ingress;
}

/*
 * Ingress
 */

action _drop() {
	drop();
}

action _nop() {
}

action set_mid(mid){
	modify_field(ipv4.ttl, ipv4.ttl - 1);
	modify_field(intrinsic_metadata.mcast_grp, mid);	
}

action set_dmac(dmac) {
	modify_field(ethernet.dstAddr, dmac);
}

table multicast {
	reads {
		standard_metadata.ingress_port : exact;
	}
	actions {
		set_mid;
		_drop;
	}
	default_action: _drop;
	size: 512;
}

table forward {
	reads {
		standard_metadata.egress_port : exact;
	}
	actions {
		set_dmac;
		_nop;
		_drop;
	}
	size: 512;
}


action set_dip(dip) {
	modify_field(ipv4.dstAddr, dip);
	modify_field(udp.checksum, 0);
}

table icn_to_ip {
	reads {
		standard_metadata.egress_port : exact;
	}
	actions {
		set_dip;
		_nop;
		_drop;
	}
	size: 512;
}

table handle_arp {
  reads {
    arp_ipv4.tpa: lpm;
    arp.oper: exact;
  }
  actions {
    forward_arp;
    _nop;
  }
  default_action : reply_arp;

  size: 256;
}

action forward_arp(port){
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

  modify_field(arp.oper, ARP_OPER_REPLY);
  modify_field(standard_metadata.egress_spec, standard_metadata.ingress_port);
}

table just_drop {
	actions {
		_drop;
	}
	default_action : _drop;
	size: 256;
}

control ingress {
	if(valid(ipv4)) {
		apply(multicast);
	}

	if(valid(arp)) {
		apply(handle_arp);
	}
}

control egress {
	if (valid(ipv4)) {
		if(valid(udp)){
			apply(icn_to_ip);	
		}
		apply(forward);
	} 

	if(valid(arp)){
		
	} else {
		if (standard_metadata.egress_port == standard_metadata.ingress_port or ipv4.ttl == 0) {
			apply(just_drop);
		}	
	}
}
