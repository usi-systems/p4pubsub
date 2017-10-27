#!/usr/bin/env python
import sys
import signal
from linear_road import LRModel
from lr_clients import LRConsumer

port = int(sys.argv[1])
consumer = LRConsumer(port=port)

def signalHandler(signal, frame):
    consumer.close()
    sys.exit(0)

signal.signal(signal.SIGINT, signalHandler)

lrm = LRModel()

while True:
    msg = consumer.recv()
    print msg
    lrm.newMsg(msg)
