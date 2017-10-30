#!/usr/bin/env python
import sys
import argparse
from controller_rpc import RPCClient
from datasource import LRDataSource
from lr_proto import LRProducer, LRConsumer, AccntBalReq, parseHostAndPort
from time import sleep

parser = argparse.ArgumentParser(description='Send stream from a file')
parser.add_argument('filename', help='Data source file', type=str)
parser.add_argument('dst', help='host:port to send messages to', type=str)
args = parser.parse_args()

toll_settings = dict(min_spd=40, min_cars=5, base_toll=1)

dst_host, dst_port = parseHostAndPort(args.dst)
producer = LRProducer(dst_host, dst_port)
cont = RPCClient()
cont.setToll(**toll_settings)

with LRDataSource(args.filename) as ds:
    for msg in ds:
        producer.send(msg)
        sleep(0.005)
