#!/usr/bin/env python
import sys, struct, socket
from time import sleep

host, port = sys.argv[1], int(sys.argv[2])

labels = sys.argv[3:]
labels = map(lambda x: int(x), labels)
labels = zip(labels[::3], labels[1::3], labels[2::3])

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.settimeout(3)
if host == '255.255.255.255':
    s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)

for lbl in labels:
    lm, lm_port, dst = lbl
    hdr = struct.pack("!I B I", lm, lm_port, dst)
    s.sendto(hdr, (host, port))
    sleep(0.01)
    print "Sent", lbl
