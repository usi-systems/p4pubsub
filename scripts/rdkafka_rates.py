#!/usr/bin/env python

# Print timeseries of throughput from rdkafka_performance

import sys

filename = "-"

MB = 1024 * 1024

elapsed = 0
cum_bytes = 0

with (sys.stdin if filename == "-" else open(filename, 'r')) as f:
    for line in f:
        if line[0] != '|': continue
        cols = line.split('|')
        if 'elapsed' in cols[1]: continue
        elapsed2 = int(cols[1])
        cum_bytes2 = int(cols[3])
        #rate = float(cols[7])
        bps = (cum_bytes2 - cum_bytes) / ((elapsed2 - elapsed) / 1000.)
        mbps = bps / MB
        print "%d\t%f" % ((elapsed / 1000), mbps)
        elapsed = elapsed2
        cum_bytes = cum_bytes2
