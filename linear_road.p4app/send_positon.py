#!/usr/bin/env python
import socket, sys
from time import sleep
from linear_road import packPosReport, LRMsg
from controller_rpc import RPCClient

def log(x): sys.stderr.write(str(x) + ' ')

host_and_port = sys.argv[1].split(':')
assert len(host_and_port) >= 1

if len(host_and_port) == 1:
    send_addr = (host_and_port[0], 1234)
else:
    send_addr = (host_and_port[0], int(host_and_port[1]))

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

def sendPr(pr):
    data = packPosReport(**pr)
    sock.sendto(data, send_addr)

cont = RPCClient()

loc = dict(xway=1, lane=1, dir=0, seg=3)

assert cont.getStoppedCnt(**loc) == 0

sendPr(LRMsg(time=0, vid=1, spd=12, xway=1, lane=1, dir=0, seg=3))
assert cont.getStoppedCnt(**loc) == 0

sendPr(LRMsg(time=0, vid=1, spd=0, xway=1, lane=1, dir=0, seg=3))
assert cont.getStoppedCnt(**loc) == 1

sendPr(LRMsg(time=0, vid=1, spd=0, xway=1, lane=1, dir=0, seg=3))
assert cont.getStoppedCnt(**loc) == 1

sendPr(LRMsg(time=0, vid=2, spd=0, xway=1, lane=1, dir=0, seg=3))
assert cont.getStoppedCnt(**loc) == 2

sendPr(LRMsg(time=0, vid=3, spd=33, xway=1, lane=1, dir=0, seg=3))
assert cont.getStoppedCnt(**loc) == 2

sendPr(LRMsg(time=0, vid=2, spd=5, xway=1, lane=1, dir=0, seg=3))
assert cont.getStoppedCnt(**loc) == 1

sendPr(LRMsg(time=0, vid=1, spd=0, xway=1, lane=1, dir=0, seg=4))
assert cont.getStoppedCnt(**loc) == 0

loc['seg'] = 4
assert cont.getStoppedCnt(**loc) == 1

print "vid 1", cont.getVidState(vid=1)
print "vid 2", cont.getVidState(vid=2)
print "vid 3", cont.getVidState(vid=3)

sleep(0.1)
