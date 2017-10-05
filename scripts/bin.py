#!/usr/bin/env python

import sys

binsize = int(sys.argv[1])
filename = sys.argv[2]

bin_value = None
bin_cnt = 0

def getbin(t):
    return t / binsize

with (sys.stdin if filename == '-' else open(filename, 'r')) as fd:
    for line in fd:
        t = int(line.split()[0])
        b = getbin(t)

        if b == bin_value:
            bin_cnt += 1
        else:
            if bin_value is not None:
                print "%d\t%d" % (bin_value, bin_cnt)
            bin_value = b
            bin_cnt = 1

print "%d\t%d" % (bin_value, bin_cnt)
