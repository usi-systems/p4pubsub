#!/usr/bin/env python

import sys

shift = float(sys.argv[1])
filename = sys.argv[2]

with (sys.stdin if filename == '-' else open(filename, 'r')) as fd:
    for line in fd:
        x, y = map(float, line.split())

        print "%g\t%g" % (x+shift, y)
