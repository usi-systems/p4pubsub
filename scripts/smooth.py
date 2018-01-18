#!/usr/bin/env python

import sys
import numpy as np

window_size = int(sys.argv[1])
filename = sys.argv[2]

with (sys.stdin if filename == '-' else open(filename, 'r')) as fd:
    window = []
    for line in fd:
        x, y = map(float, line.split())

        window.insert(0, y)
        if len(window) > window_size: window.pop()
        if len(window) != window_size: continue

        avg = np.mean(window)
        print "%g\t%g" % (x, avg)
