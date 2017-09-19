#!/usr/bin/env python

import sys
import numpy as np
from datetime import datetime
import time

filename = sys.argv[1]

latencies = []

def getTs(line):
    t = datetime.strptime(line.split()[0][1:-1].split('.')[0], "%H:%M:%S").replace(year=1970)
    ms = int(line.split()[0][1:-1].split('.')[1])
    ts = (time.mktime(t.timetuple()) * 1e6) + (ms * 1e3)
    return ts

def getPktId(line):
    pktid = line.split('] [', 5)[4]
    return map(int, pktid.split('.'))

packet_start_ts = {}

with (sys.stdin if filename == '-' else open(filename, 'r')) as fd:
    for line in fd:
        if "ig:Processing packet received on port " in line:
            pktid = getPktId(line)
            start_ts = getTs(line)
            packet_start_ts[pktid[0]] = start_ts

        if "Transmitting packet of size " in line:
            pktid = getPktId(line)
            # XXX: the value is 1 when using mcast (0 goes out port 0)
            if pktid[1] == 0: continue

            start_ts = packet_start_ts[pktid[0]]
            delta = getTs(line) - start_ts
            del packet_start_ts[pktid[0]]

            latencies.append(delta)

print "n:", len(latencies)
print "p10:", np.percentile(latencies, 10)
print "min:", np.min(latencies)
print "max:", np.max(latencies)
print "avg:", np.mean(latencies)
print "std:", np.std(latencies)

