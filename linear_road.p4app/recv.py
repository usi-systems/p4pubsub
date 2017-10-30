#!/usr/bin/env python
import sys
import signal
import argparse
from linear_road import PosReport, LRModel
from lr_proto import LRConsumer, AccntBalReq

parser = argparse.ArgumentParser(description='Receive a stream of messages')
parser.add_argument('--port', '-p', help='Listen port', type=int, default=1234)
args = parser.parse_args()

consumer = LRConsumer(args.port)
lrm = LRModel()

def handleMsg(msg):
    print msg
    lrm.newMsg(msg)

def signalHandler(signal, frame):
    while consumer.hasNewMsg():
        handleMsg(consumer.recv())
    consumer.close()
    sys.exit(0)

signal.signal(signal.SIGINT, signalHandler)

while True:
    handleMsg(consumer.recv())
