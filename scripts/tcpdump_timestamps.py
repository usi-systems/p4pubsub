#!/usr/bin/env python

# Print timestamps in microseconds from tcpdump

import sys

filename = "-"

with (sys.stdin if filename == "-" else open(filename, 'r')) as f:
    for line in f:
        if not line.strip(): continue
        ts = line.split()[0]
        secs = float(ts.split(':')[-1])
        us = secs * 1e6
        print int(us)

