#!/usr/bin/env python
import socket, sys
import signal
from linear_road import unpackPosReport, unpackLRMsg

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind(('', int(sys.argv[1])))

msgs = []

def checkMsgs():
    for i,msg in enumerate(msgs):
        print msg

def signalHandler(signal, frame):
    sock.close()
    checkMsgs()
    sys.exit(0)

signal.signal(signal.SIGINT, signalHandler)

while True:
    data, addr = sock.recvfrom(1024)
    if not data: break

    msg = unpackLRMsg(data)

    msgs.append(msg)
