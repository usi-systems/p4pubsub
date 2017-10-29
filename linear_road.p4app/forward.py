#!/usr/bin/env python
import sys
import signal
import argparse
from linear_road import PosReport
from lr_proto import LRProducer, LRConsumer, AccntBalReq, parseHostAndPort

parser = argparse.ArgumentParser(description='Forward stream of LR messages')
parser.add_argument('dst', help='host:port to forward messages to', type=str)
parser.add_argument('--port', '-p', help='Listen port', type=int, default=1234)
args = parser.parse_args()

consumer = LRConsumer(args.port)
dst_host, dst_port = parseHostAndPort(args.dst)
producer = LRProducer(dst_host, dst_port)

def signalHandler(signal, frame):
    consumer.close()
    producer.close()
    sys.exit(0)

signal.signal(signal.SIGINT, signalHandler)

while True:
    msg = consumer.recv()
    if isinstance(msg, PosReport): continue
    if isinstance(msg, AccntBalReq): continue
    print msg
    producer.send(msg)
