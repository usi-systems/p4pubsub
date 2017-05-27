#!/usr/bin/env python
import signal, sys, struct, socket

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(('', int(sys.argv[1])))

def signal_handler(signal, frame):
    sys.exit(0)
signal.signal(signal.SIGINT, signal_handler)

while True:
    hdr, addr = s.recvfrom(1024)
    tag, f = struct.unpack("!32s B", hdr)
    tag = bytearray(tag)
    sys.stderr.write("Got tag %s %d" % (tag, f))
    s.sendto(struct.pack('!I B', 4, 0), addr)
