#!/usr/bin/env python
import signal, sys, struct, socket, argparse
import time
import threading

from camus import *

def parseControllerAddr(s):
    parts = s.split(':')
    host = parts[0]
    if len(parts) == 1:
        port = 121212
    elif len(parts) == 2:
        port = int(parts[1])
    else:
        raise Exception("Malformed controller address: " + s)

    return (host, port)

class Consumer:

    def __init__(self, port, controller_addr=('127.0.0.1', 121212)):
        self.port = port
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind(('', port))

        self.controller_addr = controller_addr

        self.new_record_callbacks = []
        self.subscriptions = []

    def subscribe(self, topics):
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect(self.controller_addr)
        s.send('sub\t:%d\t'%self.port + '\t'.join(topics))
        s.close()

    def onNewRecord(self, cb):
        self.new_record_callbacks.append(cb)

    def start(self):
        self.listen_thread = threading.Thread(target=self.run)
        self.listen_thread.daemon = True
        self.listen_thread.start()

    def stop(self):
        self.sock.close()

    def run(self):
        while True:
            data, addr = self.sock.recvfrom(2048)
            self.processPkt(data, addr)

    def processPkt(self, data, addr):
        topic = data[:TAG_SIZE].lstrip('\x00')
        payload = data[TAG_SIZE:]

        for cb in self.new_record_callbacks:
            cb(topic, payload)


start_time = None
msgs_received = 0
bytes_received = 0

def handleNewRecord(tag, record):
    global start_time, msgs_received, bytes_received
    if start_time is None: start_time = time.time()
    msgs_received += 1
    bytes_received += len(record)


stats_waiter = threading.Event()

def signal_handler(signal, frame):
    global start_time, msgs_received, bytes_received
    print "\ntotal received:", msgs_received
    if start_time and msgs_received: print "avg rate:", msgs_received / float(time.time() - start_time), "msg/s"
    stats_waiter.set()
    c.stop()
    sys.exit(0)
signal.signal(signal.SIGINT, signal_handler)

def stats_thread():
    interval_s = 3
    time.sleep(0.1)
    while True:
        msgs_before = msgs_received
        bytes_before = bytes_received
        if stats_waiter.wait(interval_s):
            break
        if msgs_before is None: continue
        rate = (msgs_received - msgs_before) / float(interval_s)
        mbps = (bytes_received - bytes_before) / float(interval_s)
        print "%.2f pkt/s (%.2f MB/s)" % (rate, mbps/1024/1024)

parser = argparse.ArgumentParser()
parser.add_argument("port", type=int, help="port to listen on")
parser.add_argument("-c", "--controller", type=str, help="controller address", default='127.0.0.1:12121')
parser.add_argument("-t", "--topics", type=lambda s: s.split(','), help="topics to subscribe to", default=['default'])
args = parser.parse_args()

controller_addr = parseControllerAddr(args.controller)

t = threading.Thread(target=stats_thread)
t.daemon = True
t.start()

c = Consumer(args.port, controller_addr)
c.onNewRecord(handleNewRecord)
c.subscribe(args.topics)
c.start()

while True:
    time.sleep(5)
