#!/usr/bin/env python
import sys, struct, socket

tag = int(sys.argv[1], 16)
host, port = sys.argv[2], int(sys.argv[3])

hdr = struct.pack("!I B", tag, 0)
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.settimeout(3)
if host == '255.255.255.255':
    s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
s.sendto(hdr, (host, port))
