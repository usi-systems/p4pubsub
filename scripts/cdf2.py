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

#plt.style.use('ggplot')
matplotlib.rcParams.update({'font.size': 24})
matplotlib.rcParams.update({'font.weight': 'bold'})
matplotlib.rcParams.update({'axes.labelweight': 'bold'})
matplotlib.rcParams.update({'text.color': 'black'})


filenames = sys.argv[1::2]
labels = sys.argv[2::2]
assert len(filenames) == len(labels)

cdfs = {}

def mk_cdf(label, filename):
    data = np.loadtxt(filename)
    data = [x / 1000 for x in data] # change unit of x axis
    sorted_data = np.sort(data)
    yvals=np.arange(len(sorted_data))/float(len(sorted_data)-1)
    cdfs[label] = (sorted_data, yvals)

threads = [Thread(target=mk_cdf, args=(lbl, fn)) for lbl,fn in zip(labels, filenames)]
for t in threads: t.start()
for t in threads: t.join()

color = cycle(['r', 'g', 'b', 'c', 'y', 'k', 'm'])
#linestyles = cycle(("-","-.","--",":"))
linestyles = cycle(("-"))


for lbl in labels:
    xs, ys = cdfs[lbl]
    plt.plot(xs, ys, label=lbl, linestyle=next(linestyles), color=next(color), linewidth=4)


# Display grid
plt.axes().grid()

#plt.axes().set_xscale("log", nonposx='clip')

ticks_x = ticker.FuncFormatter(lambda x, pos: '%g'%x if x<1e3 else '{0:1.0e}'.format(x).replace('+0', ''))
plt.axes().get_xaxis().set_major_formatter(ticks_x)

plt.xlabel('Latency (us)')
plt.ylabel('CDF')
plt.tight_layout()

leg = plt.legend(loc='lower right')
#leg.get_frame().set_alpha(0.0)
#leg.get_frame().set_linewidth(0.0)

transparent_png = False
plt.savefig('cdf.pdf')
plt.savefig('cdf.png', transparent=transparent_png)

plt.show()

# Zoom in
plt.xlim([0,500])
plt.savefig('cdf_zoomed0.pdf')
plt.savefig('cdf_zoomed0.png', transparent=transparent_png)
plt.xlim([0,300])
plt.savefig('cdf_zoomed1.pdf')
plt.savefig('cdf_zoomed1.png', transparent=transparent_png)
plt.xlim([0,100])
plt.savefig('cdf_zoomed2.pdf')
plt.savefig('cdf_zoomed2.png', transparent=transparent_png)
plt.xlim([0,50])
plt.savefig('cdf_zoomed3.pdf')
plt.savefig('cdf_zoomed3.png', transparent=transparent_png)
plt.xlim([0,30])
plt.savefig('cdf_zoomed4.pdf')
plt.savefig('cdf_zoomed4.png', transparent=transparent_png)
plt.xlim([0,20])
plt.savefig('cdf_zoomed5.pdf')
plt.savefig('cdf_zoomed5.png', transparent=transparent_png)
plt.xlim([0,10])
plt.savefig('cdf_zoomed6.pdf')
plt.savefig('cdf_zoomed6.png', transparent=transparent_png)
plt.xlim([5,20])
#plt.ylim([0.8,1.0])
plt.savefig('cdf_zoomed7.pdf')
plt.savefig('cdf_zoomed7.png', transparent=transparent_png)
plt.xlim([0,50])
plt.ylim([0.96,1.0])
leg.remove()
plt.savefig('cdf_zoomed8.pdf')
plt.savefig('cdf_zoomed8.png', transparent=transparent_png)
