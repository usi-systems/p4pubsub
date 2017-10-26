#!/usr/bin/env python
import socket, sys
import signal
from linear_road import unpackPosReport, unpackLRMsg, LRModel

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind(('', int(sys.argv[1])))

def signalHandler(signal, frame):
    sock.close()
    sys.exit(0)

signal.signal(signal.SIGINT, signalHandler)

lrm = LRModel()

while True:
    data, addr = sock.recvfrom(1024)
    if not data: break

    msg = unpackLRMsg(data)
    print msg
    lrm.newMsg(msg)
