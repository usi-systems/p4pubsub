#!/usr/bin/env python

import sys

x_from = float(sys.argv[1])
x_to = float(sys.argv[2])
filename = sys.argv[3]

with (sys.stdin if filename == '-' else open(filename, 'r')) as fd:
    for line in fd:
        x, y = map(float, line.split())
        if x < x_from or x_to < x: continue

        print "%g\t%g" % (x, y)
