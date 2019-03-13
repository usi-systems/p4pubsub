#!/usr/bin/env python
import argparse
import sys
import socket
import random
import time
from threading import Thread
from scapy.all import sendp, sniff, send, get_if_list, get_if_hwaddr
from scapy.all import Ether, IP, UDP
from scapy.fields import ByteField, ShortField, BitField
from scapy.packet import Packet, bind_layers

CTRL_TYPE_CLR   = 1
CTRL_TYPE_RESP  = 32

class CtrlHdr(Packet):
    name = "CtrlHdr"
    fields_desc = [
            ByteField("ctrl_type", 0),
            ShortField("tile_id", 0),
            BitField("portmap", 0, 64)
            ]

bind_layers(UDP, CtrlHdr, dport=1235)
bind_layers(UDP, CtrlHdr, sport=1235)


pkt_received = [False]

def get_if():
    ifs=get_if_list()
    iface=None # "h1-eth0"
    for i in get_if_list():
        if "eth0" in i:
            iface=i
            break;
    if not iface:
        print "Cannot find eth0 interface"
        exit(1)
    return iface



def handle_pkt(pkt):
    assert CtrlHdr in pkt

    # Ignore the packet that we just sent:
    if pkt[CtrlHdr].ctrl_type == CTRL_TYPE_CLR: return False
    #pkt.show2()
    pkt[CtrlHdr].show2()

    sys.stdout.flush()

    pkt_received[0] = True
    return True

def main():

    if len(sys.argv) != 3:
        print 'Usage: %s HOST CLEARMAP' % sys.argv[0]
        exit(1)

    addr = socket.gethostbyname(sys.argv[1])
    iface = get_if()

    clear_pmap = int(sys.argv[2])

    tile_id = 1
    ctrl_hdr = CtrlHdr(ctrl_type=CTRL_TYPE_CLR, tile_id=tile_id, portmap=clear_pmap)

    pkt = Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff')
    pkt = pkt / IP(dst=addr) / UDP(dport=1235, sport=random.randint(49152,65535)) / ctrl_hdr


    def send_thread():
        time.sleep(0.1) # wait for sniff to be ready
        sendp(pkt, iface=iface, verbose=False)

    Thread(target=send_thread).start()

    sniff(iface=iface,
            timeout=8,
            stop_filter=handle_pkt)

    if not pkt_received[0]:
        sys.stderr.write("Scapy sniff timed out\n")


if __name__ == '__main__':
    main()
