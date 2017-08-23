#!/usr/bin/env python
import sys, struct, socket
import time
import argparse
import threading

from camus import *

# Source: http://blog.gregburek.com/2011/12/05/Rate-limiting-with-decorators/
def RateLimited(maxPerSecond):
    minInterval = 1.0 / float(maxPerSecond)
    def decorate(func):
        lastTimeCalled = [0.0]
        def rateLimitedFunction(*args,**kargs):
            elapsed = time.clock() - lastTimeCalled[0]
            leftToWait = minInterval - elapsed
            if leftToWait>0:
                time.sleep(leftToWait)
            ret = func(*args,**kargs)
            lastTimeCalled[0] = time.clock()
            return ret
        return rateLimitedFunction
    return decorate

parser = argparse.ArgumentParser()
parser.add_argument("topic", type=str, help="topic to send")
parser.add_argument("host", type=str, help="server hostname")
parser.add_argument("port", type=int, help="server port")
parser.add_argument("-s", "--size", type=int, help="record size in bytes", default=512)
parser.add_argument("-r", "--rate", type=int, help="rate (throughput) in messages per second", default=100000)
parser.add_argument("-c", "--count", type=int, help="send this many packets", default=None)
parser.add_argument("-t", "--duration", type=float, help="produce for this much time (s)", default=None)
parser.add_argument("-b", "--bind-host", type=str, help="hostname to bind socket to", default='')
args = parser.parse_args()


class Producer:

    def __init__(self, (bind_host, bind_port), (host, port)):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind((bind_host, bind_port))
        #self.sock.settimeout(3)

        if host == '255.255.255.255':
            self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)

        self.send_addr = (host, port)
        local_host, local_port = self.sock.getsockname()
        self.local_addr = (socket.inet_aton(local_host), local_port)


    def start(self):
        self.listen_thread = threading.Thread(target=self.run)
        self.listen_thread.daemon = True
        self.listen_thread.start()

    def stop(self):
        self.sock.close()

    def run(self):
        while True:
            try:
                data, addr = self.sock.recvfrom(2048)
                self.processPkt(data, addr)
            except Exception as e:
                raise e
                break

    def sendRecord(self, topic, payload):
        host, port = self.local_addr
        hdr = topic[:32].rjust(32, '\x00')
        data = hdr + payload

        self.sendPkt(data, self.send_addr)

    @RateLimited(args.rate)
    def sendPkt(self, data, addr):
        self.sock.sendto(data, addr)

p = Producer((args.bind_host, 0), (args.host, args.port))
p.start()
start_time = time.time()

seq = 0
inst_num = time.time()
while True:
    seq += 1
    record = '%d: ' % seq
    record += 'X' * (args.size - len(record))
    p.sendRecord(args.topic, record)
    if args.count is not None and seq >= args.count:
        break
    if args.duration is not None and time.time()-start_time > args.duration:
        break

p.stop()
