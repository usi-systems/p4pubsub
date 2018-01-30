#!/usr/bin/env python

import sys
import numpy as np

filenames = sys.argv[1:]

def parseTime(l):
    mins,secs = l.split()[-1][:-1].split('m')
    return int(mins)*60 + float(secs)

def parseFile(filename):
    with open(filename, 'r') as fd:
        lines = fd.readlines()
    ind_vars = map(int, lines[::8])
    dep_vars = map(parseTime, lines[6::8])
    xy = zip(ind_vars, dep_vars)
    return xy

def unzip(l): return zip(*l)

xys = map(parseFile, filenames)

xs, ys = zip(*map(unzip, xys))

xs = xs[0]
ys = zip(*ys)

means = map(np.mean, ys)
stds = map(np.std, ys)

#marginal = [(means[i]/float(xs[i])) / (means[i-1] / float(xs[i-1])) for i in range(1, len(means))]
#print np.mean(marginal), np.std(marginal)
#rows = zip(xs, marginal, [0 for _ in range(len(filenames))])

rows = zip(xs, means, stds)

print "LABEL\tqueries\truntime\tERR\tn"

for x, y, err in rows:
    print "queries\t%d\t%f\t%f\t%d" % (x, y, err, len(filenames))
