#!/usr/bin/env python
import sys, struct, socket
import time
import argparse

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
args = parser.parse_args()

# TODO: parse whole tag, not just first byte
tag = str(bytearray([args.tag]).decode().rjust(32, '\x00'))

hdr = struct.pack("!32s B", tag, 0)
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.settimeout(3)
if args.host == '255.255.255.255':
    s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)


@RateLimited(args.rate)
def sendPkt(data, addr):
    s.sendto(data, addr)

count = 0
inst_num = time.time()
while True:
    count += 1
    record = struct.pack('!I Q', inst_num, count)
    record += 'X' * (args.size - 12)
    data = hdr + record
    sendPkt(data, (args.host, args.port))
