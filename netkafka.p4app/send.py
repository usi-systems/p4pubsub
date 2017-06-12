#!/usr/bin/env python
import sys, struct, socket

tag = int(sys.argv[1], 16)
# TODO: parse whole tag, not just first byte
tag = str(bytearray([tag]).decode().rjust(32, '\x00'))
host, port = sys.argv[2], int(sys.argv[3])

#hdr = struct.pack("!I B", tag, 0)
#sys.stderr.write("Sending %s %d" % (tag, 0))
hdr = struct.pack("!32s B", tag, 0)
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.settimeout(3)
if host == '255.255.255.255':
    s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
s.sendto(hdr, (host, port))
