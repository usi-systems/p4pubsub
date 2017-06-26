#!/usr/bin/env python
import sys, struct, socket
import time
import argparse
from bloomfilter import BloomFilter
import threading
from netkafka import *

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
parser.add_argument("tag", type=lambda s: int(s, 16), help="tag to send")
parser.add_argument("host", type=str, help="server hostname")
parser.add_argument("port", type=int, help="server port")
parser.add_argument("-s", "--size", type=int, help="record size in bytes", default=512)
parser.add_argument("-r", "--rate", type=int, help="rate (throughput) in messages per second", default=100000)
parser.add_argument("-c", "--count", type=int, help="send this many packets", default=None)
parser.add_argument("-t", "--duration", type=float, help="produce for this much time (s)", default=None)
parser.add_argument("-b", "--bind-host", type=str, help="hostname to bind socket to", default='')
args = parser.parse_args()

# TODO: parse whole tag, not just first byte
tag = str(bytearray([args.tag]).decode().rjust(32, '\x00'))


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

        self.seq = 0

        self.bf_size = 8 # bytes of bloom filter for each history entry
        self.history_size = 10000 # maximum size of history to store locally
        self.R = 4 # number of history entries to send in packet

        self.history = {}

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
            except:
                break

    def processPkt(self, data, addr):
        publish, nack, retrans, sender_ip, sender_port, seq = struct.unpack("!B B B 4s H I", data[:HDR_SIZE-TAG_SIZE])
        sender_addr = (socket.inet_ntoa(sender_ip), sender_port)

        if nack:
            missing_cnt, = struct.unpack('B', data[HDR_SIZE-TAG_SIZE])
            fmt = '!' + 'I'*missing_cnt
            missing = struct.unpack(fmt, data[HDR_SIZE-TAG_SIZE+1:HDR_SIZE-TAG_SIZE+1+4*missing_cnt])
            self.retransmit(addr, missing)

    def retransmit(self, addr, missing_seqs):
        publish, nack, retrans = 0, 0, 1
        host, port = self.local_addr
        for seq in missing_seqs:

            if seq in self.history:
                tag, _, payload = self.history[seq]
            else:
                tag, payload = '\x00'*TAG_SIZE, '' # tag=0 indicates the seq couldn't be found

            hdr = struct.pack("!B B B 4s H I 32s", publish, nack, retrans, host, port, seq, tag)
            hdr += '\x00\x00' # empty history header
            data = hdr + payload

            self.sendPkt(data, addr)
        #print "retransmitting:", missing_seqs, 'to', addr


    def genBF(self, tag):
        bf = BloomFilter(self.bf_size*8, 7)
        num_tag = sum(x << i*8 for i,x in enumerate(reversed(bytearray(tag))))
        for i in range(1, 257):
            if num_tag & 1 << (i-1):
                bf.add(struct.pack('B', i))

        return bf.dump()

    def addHist(self, seq, tag, payload):
        self.history[seq] = (tag, self.genBF(tag), payload)
        todelete = seq-self.history_size
        if todelete in self.history: del self.history[todelete]

    def genHist(self):
        entry_count = min(len(self.history), self.R)
        s = struct.pack('!B B', self.bf_size, entry_count)
        for seq in range(self.seq-1, max(self.seq-1-entry_count, 0), -1):
            _, bf, _ = self.history[seq]
            s += struct.pack('!I %ss' % self.bf_size, seq, bf)
        return s

    def sendRecord(self, tag, payload):
        self.seq += 1
        publish, nack, retrans = 1, 0, 0
        host, port = self.local_addr
        hdr = struct.pack("!B B B 4s H I 32s", publish, nack, retrans, host, port, self.seq, tag)
        hdr += self.genHist()
        data = hdr + payload

        self.addHist(seq, tag, payload)

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
    p.sendRecord(tag, record)
    if args.count is not None and seq >= args.count:
        break
    if args.duration is not None and time.time()-start_time > args.duration:
        break

p.stop()
