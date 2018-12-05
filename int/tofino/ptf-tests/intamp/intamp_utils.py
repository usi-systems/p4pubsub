import os
from ptf import packet as scapy
from ptf import mask
from ptf.testutils import *
from p4header import P4Headers, p4HeaderToScapyPacket

this_dir = os.path.dirname(os.path.abspath(__file__))

P4_FILE = os.path.join(this_dir, "../../programs/intamp/intamp.p4")
p4_headers = P4Headers(P4_FILE)

IntProbeMarker = p4HeaderToScapyPacket(p4_headers['int_probe_marker_t'])
IntL4Shim = p4HeaderToScapyPacket(p4_headers['intl4_shim_t'])
IntHeader = p4HeaderToScapyPacket(p4_headers['int_header_t'])
IntSwitchId = p4HeaderToScapyPacket(p4_headers['int_switch_id_t'])
IntHopLatency = p4HeaderToScapyPacket(p4_headers['int_hop_latency_t'])
IntQOccupancy = p4HeaderToScapyPacket(p4_headers['int_q_occupancy_t'])

#class NetGrepHdr(Packet):
#    MAX_LEN=3
#    name="netgrep_state"
#    fields_desc = [
#            ByteField('state', 0),
#            ByteField('matched', 0),
#            ]


def verify_packet(test, pkt, port_id, timeout=2):
    """
    Custom verify_packet to ignore LLDP packets
    Check that an expected packet is received
    port_id can either be a single integer (port_number on default device 0)
    or a tuple of 2 integers (device_number, port_number)
    """
    device, port = port_to_tuple(port_id)
    logging.debug("Checking for pkt on device %d, port %d", device, port)
    result = dp_poll(test, device_number=device, port_number=port,
                     timeout=timeout, exp_pkt=pkt)
    nrcv = Ether().__class__(result.packet)
    while nrcv[Ether].type == 0x88cc: # ignore LLDP packets
        result = dp_poll(test, device_number=device_number, timeout=timeout)
        nrcv = Ether().__class__(result.packet)
    if isinstance(result, test.dataplane.PollFailure):
        test.fail("Expected packet was not received on device %d, port %r.\n%s"
                % (device, port, result.format()))

def maskPkt(exp_pkt):
    m = mask.Mask(exp_pkt, ignore_extra_bytes=True)
    m.set_do_not_care_scapy(IP, 'len')
    m.set_do_not_care_scapy(IP, 'chksum')
    m.set_do_not_care_scapy(UDP, 'sport') # the P4 program stores state in this field
    #m.set_do_not_care_scapy(NetGrepHdr, 'state0')
    #m.set_do_not_care_scapy(NetGrepHdr, 'state1')
    #m.set_do_not_care_scapy(NetGrepHdr, 'state2')
    return m

def int_packet(remaining_hop_cnt=1, switch_id=0, hop_latency=0, q_occupancy3=0,
               eth_dst='00:01:02:03:04:05',
               eth_src='00:06:07:08:09:0a',
               ip_src='192.168.0.1',
               ip_dst='192.168.0.2',
               ip_tos=0,
               ip_ttl=64,
               ip_id=1,
               udp_sport=4321,
               udp_dport=1234,
               udp_len=None,
               udp_chksum=None,
               ip_ihl=None
               ):

    udp_chksum = 0 # disable UDP checksums

    # DEBUG: append some padding byte
    #if udp_dport == 1233:
    #    udp_len = len(scapy.UDP()) + len(NetGrepHdr()) + len(chars) update upd len
    #    chars += 'padding' * 5
    int_bytes = len(IntL4Shim()) + len(IntHeader()) + len(IntSwitchId()) + len(IntHopLatency()) + len(IntQOccupancy())
    if udp_len == None:
        udp_len = len(scapy.UDP()) + len(IntProbeMarker()) + int_bytes
    pkt = scapy.Ether(dst=eth_dst, src=eth_src)/ \
                scapy.IP(src=ip_src, dst=ip_dst, tos=ip_tos, ttl=ip_ttl, ihl=ip_ihl, id=ip_id)/ \
                scapy.UDP(sport=udp_sport, dport=udp_dport, len=udp_len, chksum=udp_chksum)/ \
                IntProbeMarker(probe_marker1=0xefbeadde,probe_marker2=0x0df0ad8b)/ \
                IntL4Shim(int_type=1, len=int_bytes/4)/ \
                IntHeader(ver=1, remaining_hop_cnt=remaining_hop_cnt, instruction_mask_0003=11)/ \
                IntSwitchId(switch_id=switch_id)/ \
                IntHopLatency(hop_latency=hop_latency)/ \
                IntQOccupancy(q_occupancy3=q_occupancy3)

    return pkt

