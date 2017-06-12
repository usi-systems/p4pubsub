#!/usr/bin/env python
import signal, sys, struct, socket

def signal_handler(signal, frame):
    sys.exit(0)
signal.signal(signal.SIGINT, signal_handler)

bind_addr = ('', int(sys.argv[1]))

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

    def __init__(self, bind_addr):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind(bind_addr)

        self.subscriptions = dict()

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
        hdr = data[:33]
        tag, f = struct.unpack("!32s B", hdr)
        tag = sum(x << i*8 for i,x in enumerate(reversed(bytearray(tag))))

        match_count = 0
        for node, subscription in self.subscriptions.iteritems():
            if self.isSubset(tag, subscription):
                self.sock.sendto(data, node)
                match_count += 1

        if match_count < 1:
            sys.stderr.write("Tag %s didn't match any entries\n" % (tag))


router = TagRouter(bind_addr)

with open('subscriptions.txt', 'r') as f:
    router.loadSubscriptions(parseSubscriptions(f.read()))

router.start()
