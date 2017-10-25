#!/usr/bin/env python
import socket, sys
from linear_road import unpackPosReport

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind(('', int(sys.argv[1])))

while True:
    try:
        data, addr = sock.recvfrom(1024)
    except KeyboardInterrupt:
        sock.close()
        break
    pr = unpackPosReport(data)
    #sys.stderr.write(str(pr))
    print addr, pr
