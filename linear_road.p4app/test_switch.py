#!/usr/bin/env python
import sys
import argparse
from time import sleep
from linear_road import PosReport, AccidentAlert, Loc
from controller_rpc import RPCClient
from lr_proto import LRProducer, LRConsumer, parseHostAndPort

def log(x): sys.stderr.write(str(x) + ' ')


parser = argparse.ArgumentParser(description='Send stream of LR messages')
parser.add_argument('dst', help='host:port to stream LR messages to', type=str)
parser.add_argument('--port', '-p', help='Listen port', type=int, default=1235)
args = parser.parse_args()

dst_host, dst_port = parseHostAndPort(args.dst)
producer = LRProducer(dst_host, dst_port)

# To get messages that are forwarded back:
consumer = LRConsumer(args.port, timeout=0.2)

# Interface to the controller:
cont = RPCClient()

def sendPr(**pr):
    producer.send(PosReport(**pr))


loc = Loc(xway=1, lane=1, dir=0, seg=8)
segloc = Loc(loc, lane=None)

assert cont.getStoppedCnt(**loc) == 0
ss = cont.getSegState(**segloc)
assert ss['vol'] == 0, "didn't expect: %s" % str(ss['vol'])

sendPr(time=1, vid=1, spd=12, xway=1, lane=1, dir=0, seg=8)
assert cont.getStoppedCnt(**loc) == 0
assert cont.getSegState(**segloc)['vol'] == 1

sendPr(time=2, vid=1, spd=0, xway=1, lane=1, dir=0, seg=8)
assert cont.getStoppedCnt(**loc) == 1

sendPr(time=3, vid=1, spd=0, xway=1, lane=1, dir=0, seg=8)
assert cont.getStoppedCnt(**loc) == 1

# This should emit an accident alert
sendPr(time=4, vid=2, spd=0, xway=1, lane=1, dir=0, seg=8)
assert cont.getStoppedCnt(**loc) == 2
assert cont.getSegState(**segloc)['vol'] == 2

msg = consumer.recv()
assert isinstance(msg, AccidentAlert)
assert msg['time'] == 4
assert msg['vid'] == 2
assert msg['seg'] == 8

# This should emit an accident alert
sendPr(time=5, vid=3, spd=33, xway=1, lane=2, dir=0, seg=8)
assert cont.getStoppedCnt(**loc) == 2
assert cont.getSegState(**segloc)['vol'] == 3

msg = consumer.recv()
assert isinstance(msg, AccidentAlert)
assert msg['time'] == 5
assert msg['vid'] == 3
assert msg['seg'] == 8

# This should emit an accident alert
sendPr(time=6, vid=4, spd=10, xway=1, lane=3, dir=0, seg=4)

msg = consumer.recv()
assert isinstance(msg, AccidentAlert)
assert msg['time'] == 6
assert msg['vid'] == 4
assert msg['seg'] == 8
assert cont.getSegState(xway=1, seg=4, dir=0)['vol'] == 1

sendPr(time=7, vid=2, spd=5, xway=1, lane=1, dir=0, seg=8)
assert cont.getStoppedCnt(**loc) == 1
assert cont.getSegState(**segloc)['vol'] == 3

sendPr(time=8, vid=1, spd=0, xway=1, lane=1, dir=0, seg=9)
assert cont.getStoppedCnt(**loc) == 0
assert cont.getSegState(**segloc)['vol'] == 2

loc2 = Loc(loc, seg=9)
assert cont.getStoppedCnt(**loc2) == 1
assert cont.getSegState(**Loc(loc2, lane=None))['vol'] == 1

assert not consumer.hasNewMsg()

print "vid 1", cont.getVidState(vid=1)
print "vid 2", cont.getVidState(vid=2)
print "vid 3", cont.getVidState(vid=3)

