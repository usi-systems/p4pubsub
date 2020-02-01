#!/usr/bin/env python
# Calculate average and std for numbers on stdin
import sys
import numpy as np

nums = []

for l in sys.stdin:
    s = l.strip().replace(',', '')
    if s == '': continue
    nums.append(float(s))

print "%.2f +/- %.2f" % (np.mean(nums), np.std(nums))
