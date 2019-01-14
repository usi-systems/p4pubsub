/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_IPV4 = 0x800;
const bit<16> TYPE_ARP = 0x0806;

const bit<8> IP_PROT_UDP = 0x11;
const bit<8> ITCH41_MSG_ADD_ORDER = 65; // A


const bit<16> ARP_HTYPE_ETHERNET = 0x0001;
const bit<16> ARP_PTYPE_IPV4     = 0x0800;
const bit<8>  ARP_HLEN_ETHERNET  = 6;
const bit<8>  ARP_PLEN_IPV4      = 4;
const bit<16> ARP_OPER_REQUEST   = 1;
const bit<16> ARP_OPER_REPLY     = 2;

typedef bit<48>  mac_addr_t;
typedef bit<32>  ipv4_addr_t;
typedef bit<9>   port_id_t; 


/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header arp_t {
    bit<16> htype;
    bit<16> ptype;
    bit<8>  hlen;
    bit<8>  plen;
    bit<16> oper;
}

header arp_ipv4_t {
    mac_addr_t  sha;
    ipv4_addr_t spa;
    mac_addr_t  tha;
    ipv4_addr_t tpa;
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}

header udp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<16> length_;
    bit<16> checksum;
}

header moldudp_hdr_t {
    bit<80> session;
    bit<64> seq;
    bit<16> msg_cnt;
}

header moldudp_msg_t {
    bit<16> msg_len;
}


header itch_msg_type_t {
    bit<8> msg_type;
}

header itch_add_order_t {
    bit<16> stock_locate;
    bit<16> tracking_number;
    bit<48> timestamp_ns;
    bit<64> order_ref_number;
    bit<8> buy_sell_indicator;
    bit<32> shares;
    bit<64> stock;
    bit<32> price;

    bit<32> x1;
    bit<32> x2;
    bit<32> x3;
    bit<32> x4;
}

@pragma query_field(add_order.buy_sell_indicator, 8)
@pragma query_field(add_order.price, 32)
@pragma query_field(add_order.shares, 32)
@pragma query_field_exact(add_order.stock, 64)

@pragma query_field(add_order.x1, 32)
@pragma query_field(add_order.x2, 32)
@pragma query_field(add_order.x3, 32)
@pragma query_field(add_order.x4, 32)
@pragma query_field(add_order.x5, 32)
@pragma query_field(add_order.x6, 32)
@pragma query_field(add_order.x7, 32)
@pragma query_field(add_order.x8, 32)
@pragma query_field(add_order.x9, 32)
@pragma query_field(add_order.x10, 32)
@pragma query_field(add_order.x11, 32)
@pragma query_field(add_order.x12, 32)
@pragma query_field(add_order.x13, 32)
@pragma query_field(add_order.x14, 32)
@pragma query_field(add_order.x15, 32)
@pragma query_field(add_order.x16, 32)
@pragma query_field(add_order.x17, 32)

struct metadata {
    /* EMPTY {} */
}

struct headers {
    ethernet_t        ethernet;
    arp_t             arp;
    arp_ipv4_t        arp_ipv4;
    ipv4_t            ipv4;
    udp_t             udp;
    moldudp_hdr_t     mold_hdr;
    moldudp_msg_t     mold_msg;
    itch_msg_type_t   itch_msg_type;
    itch_add_order_t  add_order;
}

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser MyParser(packet_in packet,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_IPV4: parse_ipv4;
            TYPE_ARP: parse_arp;  
            default: accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            IP_PROT_UDP: parse_udp;
            default: accept;
        }
    }

    state parse_udp {
        packet.extract(hdr.udp);
        transition select(hdr.udp.dstPort) {
            1234: parse_moldudp;
            default : accept;
        }
    }

    state parse_moldudp {
        packet.extract(hdr.mold_hdr);
        packet.extract(hdr.mold_msg);
        packet.extract(hdr.itch_msg_type);
        transition select(hdr.itch_msg_type.msg_type) {
            ITCH41_MSG_ADD_ORDER: parse_add_order;
            default: accept;
        }
    }
    
    state parse_add_order {
        packet.extract(hdr.add_order);
        transition accept;
    }

     /* ARP */
    state parse_arp {
        packet.extract(hdr.arp);
        transition select(hdr.arp.htype, hdr.arp.ptype,
                          hdr.arp.hlen,  hdr.arp.plen) {
            (ARP_HTYPE_ETHERNET, ARP_PTYPE_IPV4,
             ARP_HLEN_ETHERNET,  ARP_PLEN_IPV4) : parse_arp_ipv4;
            default : accept;
        }
    }
    
    state parse_arp_ipv4 {
        packet.extract(hdr.arp_ipv4);
        transition accept;
    }            
}

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control MyVerifyChecksum(inout headers hdr, inout metadata meta) {   
    apply {  }
}


/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

#include "camus.p4"
control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    action drop() {
        mark_to_drop();
    }

    action ipv4_forward(macAddr_t dstAddr, egressSpec_t port) {
        standard_metadata.egress_spec = port;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = dstAddr;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }

    action set_arp_dmac(bit<48> dmac, bit<9> port, bit<1> reply_it) {
		if (reply_it == 1 && hdr.arp.oper != ARP_OPER_REPLY){
			bit<48> tmphd = hdr.arp_ipv4.tha;
			bit<48> tmphs = hdr.arp_ipv4.sha;

			bit<48> tmpd = hdr.ethernet.dstAddr;
			bit<48> tmps = hdr.ethernet.srcAddr;

			bit<32> tmpsip = hdr.arp_ipv4.spa;
			bit<32> tmpdip = hdr.arp_ipv4.tpa;

			hdr.ethernet.dstAddr = tmps;//tmps;
			hdr.ethernet.srcAddr = tmpd;
			
			hdr.arp.oper         = ARP_OPER_REPLY;
			
			hdr.arp_ipv4.tha     = tmphs;
			hdr.arp_ipv4.tpa     = tmpsip;
			hdr.arp_ipv4.sha     = dmac;
			hdr.arp_ipv4.spa     = tmpdip;

			standard_metadata.egress_spec = standard_metadata.ingress_port;
		} else {
			standard_metadata.egress_spec = port;
		}
	}

    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            ipv4_forward;
            drop;
        }
        size = 1024;
        default_action = drop;
    }

    table arp_forward {
		actions = {
			set_arp_dmac;
			drop;
		}
		key = {
			hdr.arp_ipv4.tpa: lpm;
		}
		size = 512;
		default_action = drop;
	}


    apply {
        if (hdr.arp.isValid()){
			arp_forward.apply();
		}else if (hdr.add_order.isValid()) {
            Camus.apply(hdr, standard_metadata);
        }
        else if (hdr.ipv4.isValid() && hdr.ipv4.ttl > 0) {
            ipv4_lpm.apply();
        }
    }
}

/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {

    action drop() {
        mark_to_drop();
    }

    action nop() {

    }

    action set_dmac_dip(macAddr_t dstAddr, ip4Addr_t dstIp) {
        hdr.ethernet.dstAddr = dstAddr;
        hdr.ipv4.dstAddr = dstIp;
        hdr.udp.checksum = 0x0;
    }

    table send_frame {
        key = {
            standard_metadata.egress_port: exact;
        }
        actions = {
            set_dmac_dip;
            nop;
        }
        size = 32;
        default_action = nop;
    }

    apply {
        if(hdr.ipv4.isValid()){
            send_frame.apply();
        }
        if(standard_metadata.ingress_port == standard_metadata.egress_port){
            if (hdr.add_order.isValid())
                drop();
        }
    }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers  hdr, inout metadata meta) {
    apply {
        update_checksum(
            hdr.ipv4.isValid(),
            { 
                hdr.ipv4.version,
                hdr.ipv4.ihl,
                hdr.ipv4.diffserv,
                hdr.ipv4.totalLen,
                hdr.ipv4.identification,
                hdr.ipv4.flags,
                hdr.ipv4.fragOffset,
                hdr.ipv4.ttl,
                hdr.ipv4.protocol,
                hdr.ipv4.srcAddr,
                hdr.ipv4.dstAddr 
            },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16
        );
    }
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.arp);
        packet.emit(hdr.arp_ipv4);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.udp);
        packet.emit(hdr.mold_hdr);
        packet.emit(hdr.mold_msg);
        packet.emit(hdr.itch_msg_type);
        packet.emit(hdr.add_order);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
