#!/usr/bin/env python

import sys
import socket

if len(sys.argv) != 3:
    print "Usage: %s LISTEN_PORT FORWARD_HOST" % sys.argv[0]
    sys.exit(1)

port = int(sys.argv[1])
forward_host = sys.argv[2]

forward_addr = (forward_host, port)

s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(('', port))

while True:
    data, addr = s.recvfrom(2048)
    s.sendto(data, forward_addr)
