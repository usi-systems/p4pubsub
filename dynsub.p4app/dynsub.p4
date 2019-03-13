/* -*- P4_16 -*- */
#include <core.p4>
#include <v1model.p4>

const bit<16> TYPE_IPV4       = 0x800;
const bit<8>  IP_PROT_UDP     = 0x11;

const bit<16> POS_UDP_PORT    = 1234;
const bit<16> CTRL_UDP_PORT   = 1235;

const bit<8>  CTRL_TYPE_CLR   = 1;
const bit<8>  CTRL_TYPE_RESP  = 32;

typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;
typedef bit<16> mcastGrp_t;


/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
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

header pos_t {
    bit<16>  id;
    bit<16>  x;
    bit<16>  y;
    bit<16>  speed;
}

header ctrl_t {
    bit<8>  ctrl_type;
    bit<16> tile_id;
    // The controller puts the ports to be removed from the portmap for this tile.
    // On response, the switch puts the most recent portmap.
    bit<64> portmap;
}


struct pos_meta_t {
    bit<8>  tile_id;
    bit<64> portmap;
}

struct metadata {
    pos_meta_t        meta;
}

struct headers {
    ethernet_t        ethernet;
    ipv4_t            ipv4;
    udp_t             udp;
    pos_t             pos;
    ctrl_t            ctrl;
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
            POS_UDP_PORT: parse_pos;
            CTRL_UDP_PORT: parse_ctrl;
            default : accept;
        }
    }

    state parse_pos {
        packet.extract(hdr.pos);
        transition accept;
    }

    state parse_ctrl {
        packet.extract(hdr.ctrl);
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

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

    register<bit<64>>(256) portMaps; // tile_id => portmap
    register<bit<64>>(256) portMapsRecent;

    action drop() {
        mark_to_drop();
    }
    action ipv4_forward(macAddr_t dstAddr, egressSpec_t port) {
        standard_metadata.egress_spec = port;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = dstAddr;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }
    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            ipv4_forward;
            drop;
            NoAction;
        }
        size = 1024;
        default_action = drop();
    }

    action set_tile_id(bit<8> tile_id) {
        meta.meta.tile_id = tile_id;
    }
    table grid {
        key = {
            hdr.pos.x: range;
            hdr.pos.y: range;
        }
        actions = {
            set_tile_id;
            NoAction;
        }
        size = 1024;
        default_action = NoAction();
    }

    action set_mgid(mcastGrp_t mgid) {
        standard_metadata.mcast_grp = mgid;
    }
    table portmap_to_mgid {
        key = {
            meta.meta.portmap: ternary;
        }
        actions = {
            set_mgid;
            drop;
        }
        size = 1024;
        default_action = drop();
    }

    // Triggered by a pos pkt from clients
    action update_portmap() {
        // A port map with the bit set for the ingress port:
        bit<64> ingr_port_bit = ((bit<64>)1) << ((bit<8>)standard_metadata.ingress_port-1);

        // Add the ingress port to the recent port map
        bit<64> portmap_recent;
        portMapsRecent.read(portmap_recent, (bit<32>)meta.meta.tile_id);
        portmap_recent = portmap_recent | ingr_port_bit;
        portMapsRecent.write((bit<32>)meta.meta.tile_id, portmap_recent);

        // Add the ingress port to the port map
        portMaps.read(meta.meta.portmap, (bit<32>)meta.meta.tile_id);
        bit<64> portmap2 = meta.meta.portmap | ingr_port_bit;
        portMaps.write((bit<32>)meta.meta.tile_id, portmap2);

    }

    // Triggered by a ctrl pkt from the control plane
    action prune_portmap() {
        // Ports the controller requests to be cleared:
        bit<64> to_clear = hdr.ctrl.portmap;

        // Read and then clear the recent portmap
        bit<64> portmap_recent;
        portMapsRecent.read(portmap_recent, (bit<32>)hdr.ctrl.tile_id);
        portMapsRecent.write((bit<32>)hdr.ctrl.tile_id, (bit<64>)0);

        // Don't remove ports that are in the recent portmap
        to_clear = to_clear & ~portmap_recent;

        // Remove old ports from portmap
        bit<64> portmap;
        portMaps.read(portmap, (bit<32>)hdr.ctrl.tile_id);
        bit<64> keep_mask = ~to_clear;
        portmap = portmap & keep_mask;
        portMaps.write((bit<32>)hdr.ctrl.tile_id, portmap);

        // Reply to the controller with recent portmap
        hdr.ctrl.portmap = portmap_recent;
        //hdr.ctrl.portmap = portmap;
        hdr.ctrl.ctrl_type = CTRL_TYPE_RESP;
        standard_metadata.egress_spec = standard_metadata.ingress_port;
    }


    apply {
        if (hdr.pos.isValid()) {
            grid.apply();
            update_portmap();
            portmap_to_mgid.apply();
        }
        else if (hdr.ctrl.isValid()) {
            prune_portmap();
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
    apply {  }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control MyComputeChecksum(inout headers  hdr, inout metadata meta) {
     apply {
	update_checksum(
	    hdr.ipv4.isValid(),
            { hdr.ipv4.version,
	      hdr.ipv4.ihl,
              hdr.ipv4.diffserv,
              hdr.ipv4.totalLen,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.hdrChecksum,
            HashAlgorithm.csum16);
    }
}

/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.udp);
        packet.emit(hdr.pos);
        packet.emit(hdr.ctrl);
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
