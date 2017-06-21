#!/usr/bin/env python
import signal, sys, struct, socket
import argparse
from netkafka import *

parser = argparse.ArgumentParser()
parser.add_argument("port", type=int, help="port to listen on")
parser.add_argument("-l", "--loss-rate", type=float, help="introduce packet loss rate", default=0)
args = parser.parse_args()

def signal_handler(signal, frame):
    sys.exit(0)
signal.signal(signal.SIGINT, signal_handler)

bind_addr = ('', int(args.port))

def parseSubscriptions(subscriptionstring):
    subscriptions = dict()
    for line in subscriptionstring.splitlines():
        host_port, topics = line.split(' ', 1)
        host, port = host_port.split(':')
        node = (host, int(port))
        if node not in subscriptions: subscriptions[node] = []
        subscriptions[node] += map(int, topics.split())
    return subscriptions


class TagRouter:

    def __init__(self, bind_addr, loss_rate=0):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind(bind_addr)

        self.subscriptions = dict()

        self.sender_map = dict()

        self.cnt = 0
        self.loss_rate = loss_rate

    def subscribe(self, node, topics):
        print node, topics
        if node not in self.subscriptions: self.subscriptions[node] = 0
        for topic in topics:
            self.subscriptions[node] |= 1 << (topic-1)

    def loadSubscriptions(self, subscriptions):
        for node, tags in subscriptions.iteritems():
            self.subscribe(node, tags)

    def isSubset(self, tag, subscriptions):
        return tag & subscriptions == tag


    def start(self):
        while True:
            data, addr = self.sock.recvfrom(2048)
            self.processPkt(data, addr)

    def processPkt(self, data, addr):
        publish, nack, retrans, sender_host, sender_port, seq = struct.unpack("!B B B I H I", data[:HDR_SIZE-TAG_SIZE])

        self.cnt += 1

        sender = (sender_host, sender_port)

        #if self.loss_rate and random.random() < self.loss_rate:
        if self.loss_rate and self.cnt % int(1/self.loss_rate) == 0:
            return # drop packet

        if publish:
            if sender not in self.sender_map: self.sender_map[sender] = addr
            tag = data[HDR_SIZE-TAG_SIZE:HDR_SIZE]
            tag = sum(x << i*8 for i,x in enumerate(reversed(bytearray(tag))))

            match_count = 0
            for node, subscription in self.subscriptions.iteritems():
                if self.isSubset(tag, subscription):
                    self.sock.sendto(data, node)
                    match_count += 1

            if match_count < 1:
                sys.stderr.write("Tag %s didn't match any entries\n" % (tag))

        if nack:
            self.sock.sendto(data, self.sender_map[sender])


router = TagRouter(bind_addr, loss_rate=args.loss_rate)

with open('subscriptions.txt', 'r') as f:
    router.loadSubscriptions(parseSubscriptions(f.read()))

router.start()
