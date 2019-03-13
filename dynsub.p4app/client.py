#!/usr/bin/env python
import argparse
import sys
import socket
import random
import time
from threading import Thread
from scapy.all import sendp, sniff, send, get_if_list, get_if_hwaddr
from scapy.all import Ether, IP, UDP

from pos_hdr import PosHdr


my_id = [0]
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
    assert PosHdr in pkt

    # Ignore the packet that we just sent:
    if pkt[PosHdr].id == my_id[0]: return False
    #pkt.show2()

    sys.stdout.flush()

    pkt_received[0] = True
    return True

def main():

    if len(sys.argv) < 3:
        print 'Usage: %s ID HOST [X Y]' % sys.argv[0]
        exit(1)

    my_id[0] = int(sys.argv[1])

    addr = socket.gethostbyname(sys.argv[2])
    iface = get_if()

    if len(sys.argv) > 4:
        x, y = map(int, sys.argv[3:5])
    else:
        x, y = 5, 5

    pos_hdr = PosHdr(id=my_id, x=x, y=y)

    pkt = Ether(src=get_if_hwaddr(iface), dst='ff:ff:ff:ff:ff:ff')
    pkt = pkt / IP(dst=addr) / UDP(dport=1234, sport=random.randint(49152,65535)) / pos_hdr


    def send_thread():
        time.sleep(0.1) # wait for sniff to be ready
        sendp(pkt, iface=iface, verbose=False)

    Thread(target=send_thread).start()

    return # for now, we don't receive

    sniff(iface=iface,
            timeout=8,
            stop_filter=handle_pkt)

    if not pkt_received[0]:
        sys.stderr.write("Scapy sniff timed out\n")


if __name__ == '__main__':
    main()
