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

labels = ['runtime' for _ in range(len(xs))]
means = map(np.mean, ys)
stds = map(np.std, ys)
rows = zip(labels, xs, means, stds)

labels = ['perquery' for _ in range(len(xs))]
perquery = [means[i]/xs[i] for i in range(len(xs))]
perquery_stds = [stds[i]/xs[i] for i in range(len(xs))]
rows += zip(labels, xs, perquery, perquery_stds)

#from scipy.stats import linregress
#print linregress(xs, rates)


print "LABEL\tnum_queries\tseconds\tERR\tn"

for lbl, x, y, err in rows:
    print "%s\t%d\t%f\t%f\t%d" % (lbl, x, y, err, len(filenames))
