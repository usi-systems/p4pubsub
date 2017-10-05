#!/usr/bin/env python

#
# Find the correlation between multiple timeseries.
#
# Each timeseries is TSV file with the format:
#
#   seconds\tvalue
#

import numpy as np
import pandas as pd
from itertools import combinations
import sys

filenames = sys.argv[1:]

def loadTs(filename):
    ts = pd.read_csv(filename, sep='\t', header=None, index_col=0)
    ts.index = pd.to_datetime(ts.index, unit='s')
    return ts

series = dict((f, loadTs(f)) for f in filenames)

corrs = [(f1, f2, series[f1].corrwith(series[f2])) for f1, f2 in combinations(filenames, 2)]

corrs.sort(key=lambda (a,b,c): float(c))

for f1, f2, corr in corrs:
    print "%s\t%s\t%f" % (f1, f2, corr)
