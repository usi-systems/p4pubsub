#!/usr/bin/env python

import sys
import numpy as np
import os
import matplotlib
from multiprocessing import Pool
havedisplay = "DISPLAY" in os.environ
if not havedisplay:
    matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
from threading import Thread
from itertools import cycle

plt.style.use('ggplot')

filenames = sys.argv[1::2]
labels = sys.argv[2::2]
assert len(filenames) == len(labels)

cdfs = {}

def mk_cdf(label, filename):
    data = np.loadtxt(filename)
    sorted_data = np.sort(data)
    yvals=np.arange(len(sorted_data))/float(len(sorted_data)-1)
    cdfs[label] = (sorted_data, yvals)

threads = [Thread(target=mk_cdf, args=(lbl, fn)) for lbl,fn in zip(labels, filenames)]
for t in threads: t.start()
for t in threads: t.join()

color = cycle(['r', 'g', 'b', 'c', 'o'])

for lbl in cdfs:
    xs, ys = cdfs[lbl]
    plt.plot(xs, ys, label=lbl, color=next(color), linewidth=3)

# change unit of x axis
scale_x = 1000
ticks_x = ticker.FuncFormatter(lambda x, pos: '{0:g}'.format(x/scale_x))
plt.axes().get_xaxis().set_major_formatter(ticks_x)

plt.xlabel('Latency (us)')
#plt.xlabel('Inter-Arrival Time (us)')
plt.ylabel('CDF (%)')
plt.tight_layout()

#plt.legend(loc='upper left')
plt.legend(loc='lower right')

transparent_png = False
plt.show()
plt.savefig('cdf.png', transparent=transparent_png)

# Zoom in
plt.xlim([0,150000])
plt.savefig('cdf_zoomed.png', transparent=transparent_png)
