#!/usr/bin/env python
import signal, sys, struct, socket
from threading import Thread
import argparse

from camus import *

def parseNodeAddr(hint_addr, control_addr):
    parts = hint_addr.split(':')
    if parts[0] == '':
        host = control_addr[0]
    port = int(parts[1])
    return (host, port)

class TagRouter:

    def __init__(self, bind_addr, controller_port=12121, loss_rate=0):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind(bind_addr)

        self.cntrl_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.cntrl_sock.bind(('', controller_port))

        self.subscriptions = dict()

        self.cnt = 0
        self.loss_rate = loss_rate

    def subscribe(self, node, topics):
        print node, topics
        if node not in self.subscriptions: self.subscriptions[node] = set()
        self.subscriptions[node].update(topics)

    def controllerThread(self):
        self.cntrl_sock.listen(5)
        while True:
            data = ''

            try:
                conn, addr = self.cntrl_sock.accept()
                while True:
                    chunk = conn.recv(2048)
                    if not chunk: break
                    data += chunk
            except:
                break

            self.handleControlMsg(data, addr)

    def handleControlMsg(self, data, addr):
        cmd = data.split('\t')
        if cmd[0] == 'sub':
            node = parseNodeAddr(cmd[1], addr)
            topics = cmd[2:]
            self.subscribe(node, topics)
        else:
            raise Exception("Unrecognized command: " + cmd)


    def routerThread(self):
        while True:
            try:
                data, addr = self.sock.recvfrom(2048)
                self.processPkt(data, addr)
            except Exception as e:
                raise e
                break

    def start(self):
        self.router_thread = Thread(target=self.routerThread)
        self.control_thread = Thread(target=self.controllerThread)
        self.router_thread.start()
        self.control_thread.start()

    def wait(self):
        self.router_thread.join()
        self.control_thread.join()

    def stop(self):
        self.sock.close()
        self.cntrl_sock.close()
        self.router_thread.join()
        self.control_thread.join()

    def processPkt(self, data, sender):
        self.cnt += 1

        #if self.loss_rate and random.random() < self.loss_rate:
        if self.loss_rate and self.cnt % int(1/self.loss_rate) == 0:
            return # drop packet

        topic = data[:TAG_SIZE].lstrip('\x00')

        match_count = 0
        for node, subscriptions in self.subscriptions.iteritems():
            if topic in subscriptions:
                self.sock.sendto(data, node)
                match_count += 1

        if match_count < 1:
            sys.stderr.write("Topic %s didn't match any entries\n" % (topic))


parser = argparse.ArgumentParser()
parser.add_argument("port", type=int, help="port for router to listen on")
parser.add_argument("-c", "--control-port", type=int, help="port for controller to listen on", default=12121)
parser.add_argument("-l", "--loss-rate", type=float, help="introduce packet loss rate", default=0)
args = parser.parse_args()

bind_addr = ('', int(args.port))

router = TagRouter(bind_addr, controller_port=args.control_port, loss_rate=args.loss_rate)

router.start()

def signal_handler(signal, frame):
    router.stop()
    sys.exit(0)
signal.signal(signal.SIGINT, signal_handler)

router.wait()
