#!/usr/bin/env python
import sys
import argparse
from time import sleep
from linear_road import PosReport, AccidentAlert, TollNotification, AccntBalReq, AccntBal, Loc
from linear_road import ExpenditureReq, ExpenditureReport, TravelEstimateReq, TravelEstimate
from controller_rpc import RPCClient
from lr_proto import LRProducer, LRConsumer, parseHostAndPort

def log(x): sys.stderr.write(str(x) + ' ')
def ewma(avg, x):
    a = 32
    return int((avg * (128 - a)) + (x * a)) >> 128

toll_settings = dict(min_spd=40, min_cars=5, base_toll=1)
def calc_toll(cars_in_seg=None):
    return toll_settings['base_toll'] * ((cars_in_seg - 50) ** 2)

last_time = 0
def ts():
    global last_time
    last_time += 1
    return last_time

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
def sendBr(**br):
    producer.send(AccntBalReq(**br))
def sendEr(**er):
    producer.send(ExpenditureReq(**er))
def sendTer(**ter):
    producer.send(TravelEstimateReq(**ter))



loc = Loc(xway=1, lane=1, dir=0, seg=8)
segloc = Loc(loc, lane=None)

# Configure toll settings
cont.setToll(**toll_settings)

assert cont.getStoppedCnt(**loc) == 0
ss = cont.getSegState(**segloc)
assert ss['vol'] == 0

# Add a car
sendPr(time=ts(), vid=1, spd=12, xway=1, lane=1, dir=0, seg=8)
assert cont.getStoppedCnt(**loc) == 0
assert cont.getSegState(**segloc)['vol'] == 1

# Stop the car (i.e. 4 consec. positions)
for _ in range(3):
    sendPr(time=ts(), vid=1, spd=12, xway=1, lane=1, dir=0, seg=8)
assert cont.getStoppedCnt(**loc) == 1

# Check that the saturating same loc countr doesn't overflow:
for _ in range(5):
    sendPr(time=ts(), vid=1, spd=12, xway=1, lane=1, dir=0, seg=8)
assert cont.getStoppedCnt(**loc) == 1

# Stop another car
for _ in range(4):
    sendPr(time=ts(), vid=2, spd=2, xway=1, lane=1, dir=0, seg=8)
assert cont.getStoppedCnt(**loc) == 2
assert cont.getSegState(**segloc)['vol'] == 2

msg = consumer.recv()
assert isinstance(msg, AccidentAlert)
assert msg['time'] == last_time
assert msg['vid'] == 2
assert msg['seg'] == 8

# This should emit an accident alert
sendPr(time=ts(), vid=3, spd=33, xway=1, lane=2, dir=0, seg=8)
assert cont.getStoppedCnt(**loc) == 2
assert cont.getSegState(**segloc)['vol'] == 3

msg = consumer.recv()
assert isinstance(msg, AccidentAlert)
assert msg['time'] == last_time
assert msg['vid'] == 3
assert msg['seg'] == 8

# This should emit an accident alert
sendPr(time=ts(), vid=4, spd=10, xway=1, lane=3, dir=0, seg=4)

msg = consumer.recv()
assert isinstance(msg, AccidentAlert)
assert msg['time'] == last_time
assert msg['vid'] == 4
assert msg['seg'] == 8
assert cont.getSegState(xway=1, seg=4, dir=0)['vol'] == 1

sendPr(time=ts(), vid=2, spd=5, xway=1, lane=2, dir=0, seg=8)
assert cont.getStoppedCnt(**loc) == 1
assert cont.getSegState(**segloc)['vol'] == 3

sendPr(time=ts(), vid=1, spd=0, xway=1, lane=1, dir=0, seg=9)
assert cont.getStoppedCnt(**loc) == 0
assert cont.getSegState(**segloc)['vol'] == 2

loc2 = Loc(loc, seg=9)
assert cont.getStoppedCnt(**loc2) == 0
assert cont.getSegState(**Loc(loc2, lane=None))['vol'] == 1


# Test EWMA
sendPr(time=ts(), vid=5, spd=10, xway=0, lane=1, dir=0, seg=1)
avg1 = cont.getVidState(vid=5)['ewma_spd']
assert avg1 == 10

sendPr(time=ts(), vid=5, spd=20, xway=0, lane=1, dir=0, seg=1)
avg2 = cont.getVidState(vid=5)['ewma_spd']
assert avg2 == ewma(avg1, 20)

sendPr(time=ts(), vid=5, spd=40, xway=0, lane=1, dir=0, seg=1)
avg3 = cont.getVidState(vid=5)['ewma_spd']
assert avg3 == ewma(avg2, 40)

# Test toll notification
for vid in [6, 7, 8, 9]:
    sendPr(time=ts(), vid=vid, spd=30, xway=0, lane=1, dir=0, seg=2)

sendPr(time=ts(), vid=5, spd=40, xway=0, lane=1, dir=0, seg=2)
avg4 = cont.getVidState(vid=5)['ewma_spd']
assert avg4 == ewma(avg3, 40)

vol = cont.getSegState(xway=0, dir=0, seg=2)['vol']
assert vol == 5
toll1 = calc_toll(cars_in_seg=vol)

msg = consumer.recv()
assert isinstance(msg, TollNotification)
assert msg['time'] == last_time
assert msg['vid'] == 5
assert msg['toll'] == toll1
assert msg['spd'] == avg4


# Move all the cars ahead, and check the next toll
for vid in [6, 7, 8, 9]:
    sendPr(time=ts(), vid=vid, spd=30, xway=0, lane=1, dir=0, seg=3)

sendPr(time=ts(), vid=5, spd=40, xway=0, lane=1, dir=0, seg=3)
avg5 = cont.getVidState(vid=5)['ewma_spd']
assert avg5 == ewma(avg4, 40)

ss = cont.getSegState(xway=0, dir=0, seg=2)
assert ss['vol'] == 0

toll2 = calc_toll(cars_in_seg=vol)

msg = consumer.recv()
assert isinstance(msg, TollNotification)
assert msg['time'] == last_time
assert msg['vid'] == 5
assert msg['toll'] == toll2
assert msg['spd'] == avg5

# Check accnt bal
sendBr(time=ts(), vid=5, qid=2)

msg = consumer.recv()
assert isinstance(msg, AccntBal)
assert msg['time'] == last_time
assert msg['vid'] == 5
assert msg['qid'] == 2
assert msg['bal'] == toll1 + toll2

# Other cars should have zero ballance
for vid in [6, 7, 8, 9]:
    sendBr(time=ts(), vid=vid, qid=3)

for _ in xrange(4):
    msg = consumer.recv()
    assert isinstance(msg, AccntBal)
    assert msg['qid'] == 3
    assert msg['bal'] == 0

assert not consumer.hasNewMsg()

# Test historical queries
sendEr(time=ts(), vid=1, qid=1, xway=1, day=1)
msg = consumer.recv()
assert isinstance(msg, ExpenditureReport)
assert msg['time'] == last_time
assert msg['emit'] == last_time
assert msg['qid'] == 1
assert msg['bal'] == 10

sendEr(time=ts(), vid=1, qid=2, xway=1, day=3)
msg = consumer.recv()
assert isinstance(msg, ExpenditureReport)
assert msg['time'] == last_time
assert msg['emit'] == last_time
assert msg['qid'] == 2
assert msg['bal'] == 12

sendEr(time=ts(), vid=1, qid=3, xway=2, day=2)
msg = consumer.recv()
assert isinstance(msg, ExpenditureReport)
assert msg['time'] == last_time
assert msg['emit'] == last_time
assert msg['qid'] == 3
assert msg['bal'] == 14

sendEr(time=ts(), vid=2, qid=4, xway=1, day=1)
msg = consumer.recv()
assert isinstance(msg, ExpenditureReport)
assert msg['time'] == last_time
assert msg['emit'] == last_time
assert msg['qid'] == 4
assert msg['bal'] == 16

sendEr(time=ts(), vid=2, qid=5, xway=1, day=2)
msg = consumer.recv()
print msg
assert isinstance(msg, ExpenditureReport)
assert msg['time'] == last_time
assert msg['emit'] == last_time
assert msg['qid'] == 5
assert msg['bal'] == 0

sendEr(time=ts(), vid=3, qid=6, xway=1, day=2)
msg = consumer.recv()
assert isinstance(msg, ExpenditureReport)
assert msg['time'] == last_time
assert msg['emit'] == last_time
assert msg['qid'] == 6
assert msg['bal'] == 0

assert not consumer.hasNewMsg()

# Test travel estimates

# Forwards 2 segs
sendTer(time=ts(), qid=1, xway=0, seg_init=0, seg_end=1, dow=0, tod=0)
msg = consumer.recv()
assert isinstance(msg, TravelEstimate)
assert msg['qid'] == 1
assert msg['travel_time'] == 10
assert msg['toll'] == 3

# Forwards 4 segs
sendTer(time=ts(), qid=2, xway=0, seg_init=0, seg_end=3, dow=0, tod=0)
msg = consumer.recv()
assert isinstance(msg, TravelEstimate)
assert msg['qid'] == 2
assert msg['travel_time'] == 20
assert msg['toll'] == 10

# Backwards
sendTer(time=ts(), qid=3, xway=1, seg_init=3, seg_end=1, dow=0, tod=0)
msg = consumer.recv()
assert isinstance(msg, TravelEstimate)
assert msg['qid'] == 3
assert msg['travel_time'] == 12
assert msg['toll'] == 6

# Different xway, dow and tod
sendTer(time=ts(), qid=4, xway=2, seg_init=5, seg_end=9, dow=2, tod=3)
msg = consumer.recv()
assert isinstance(msg, TravelEstimate)
assert msg['qid'] == 4
assert msg['travel_time'] == 10
assert msg['toll'] == 15

assert not consumer.hasNewMsg()

print "vid 1", cont.getVidState(vid=1)
print "vid 2", cont.getVidState(vid=2)
print "vid 3", cont.getVidState(vid=3)

