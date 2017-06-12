#!/usr/bin/env python
import signal, sys, struct, socket

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(('', int(sys.argv[1])))

def signal_handler(signal, frame):
    sys.exit(0)
signal.signal(signal.SIGINT, signal_handler)

while True:
    data, addr = s.recvfrom(2048)
    hdr = data[:33]
    tag, f = struct.unpack("!32s B", hdr)
    tag = bytearray(tag)
    tag = sum(x << i*8 for i,x in enumerate(reversed(bytearray(tag))))
    sys.stderr.write("Got tag %s %d\n" % (tag, f))
