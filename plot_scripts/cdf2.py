#!/usr/bin/env python

import sys
import numpy as np
import matplotlib.pyplot as plt

filename1, filename2 = sys.argv[1], sys.argv[2]
lbl1, lbl2 = sys.argv[3], sys.argv[4]

def mk_cdf(filename):
    data = np.loadtxt(filename)
    sorted_data = np.sort(data)
    yvals=np.arange(len(sorted_data))/float(len(sorted_data)-1)
    return (sorted_data, yvals)

xs1, ys1 = mk_cdf(filename1)
xs2, ys2 = mk_cdf(filename2)

plt.plot(xs1, ys1, label=lbl1, color='r')
plt.plot(xs2, ys2, label=lbl2, color='g')

#plt.xlim([0,0.007])
#plt.legend(loc='upper left')
plt.legend(loc='lower right')

plt.show()
