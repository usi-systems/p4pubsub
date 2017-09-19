#!/usr/bin/env python

import numpy as np
import sys

filename = sys.argv[1]

latencies = []

with (sys.stdin if filename == '-' else open(filename, 'r')) as fd:
    for line in fd:
        latencies.append(int(line))

print "n:", len(latencies)
print "min:", np.min(latencies)
print "max:", np.max(latencies)
print "avg:", np.mean(latencies)
print "std:", np.std(latencies)
