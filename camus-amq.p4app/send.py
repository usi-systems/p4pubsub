#!/usr/bin/env python
import sys, struct, socket

topic, payload = sys.argv[1], sys.argv[2]

hdr = topic[:32].rjust(32, '\x00')
host, port = sys.argv[3], int(sys.argv[4])

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.settimeout(3)
if host == '255.255.255.255':
    s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
s.sendto(hdr+payload, (host, port))
