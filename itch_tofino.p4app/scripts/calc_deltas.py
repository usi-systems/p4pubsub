#!/usr/bin/env python

import sys
import numpy as np

filename = sys.argv[1]

last_ts = None
with (sys.stdin if filename == '-' else open(filename, 'r')) as fd:
    for line in fd:
        ts = int(line.split()[0])

        if last_ts is not None:
            delta = ts - last_ts
            print delta

        last_ts = ts
