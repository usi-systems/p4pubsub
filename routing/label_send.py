#!/usr/bin/env python
import sys, struct, socket

lm, lm_port, dst = int(sys.argv[1], 16), int(sys.argv[2], 16), int(sys.argv[3], 16)
hdr = struct.pack("!I B I", lm, lm_port, dst)
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.settimeout(3)
s.sendto(hdr, (sys.argv[-2], int(sys.argv[-1])))

#sys.stderr.write("received '%s' from %s\n" % s.recvfrom(1024))
