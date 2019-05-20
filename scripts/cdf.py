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
from itertools import cycle

fontsize = 24
#plt.style.use('ggplot')
matplotlib.rcParams.update({'font.size': fontsize})
#matplotlib.rcParams.update({'font.weight': 'bold'})
#matplotlib.rcParams.update({'axes.labelweight': 'bold'})
matplotlib.rcParams.update({'text.color': 'black'})
#matplotlib.rcParams.update({'text.usetex': True})


filenames = sys.argv[1::2]
labels = sys.argv[2::2]
assert len(filenames) == len(labels)

cdfs = {}

def load_cdf(filename):
    data = np.loadtxt(filename, delimiter='\t')
    xs, freqs = data.transpose()
    ys = np.cumsum(freqs) / float(sum(freqs)) # calculate percentiles
    return (xs, ys)

for lbl,fn in zip(labels, filenames):
    cdfs[lbl] = load_cdf(fn)
    #percentiles = [99.99, 99.9, 99, 95, 90, 75, 50]
    #print lbl, [cdfs[lbl][1][p] for p in percentiles]


#colors = cycle(['r', 'b', 'r', 'c', 'y', 'k', 'm'])
colors = cycle(('#b2abd2', '#e66101', '#5e3c99', '#fdb863'))
#linestyles = cycle(("-","-.","--",":"))
linestyles = cycle(("-"))

colormap = dict(NewOrder='r', Payment='g', OrderStatus='b', StockLevel='c', Delivery='y')


for lbl in labels:
    xs, ys = cdfs[lbl]
    c = colormap[lbl] if lbl in colormap else next(colors)
    plt.plot(xs, ys, label=lbl, linestyle=next(linestyles), color=c, linewidth=3)


# Display grid
plt.axes().grid()

#plt.axes().set_xscale("log", nonposx='clip')

#ticks_x = ticker.FuncFormatter(lambda x, pos: '%g'%x if x<1e3 else '{0:1.0e}'.format(x).replace('+0', ''))
#plt.axes().get_xaxis().set_major_formatter(ticks_x)
#
#ticks_y = ticker.FuncFormatter(lambda x, pos: '%g'%x)
#plt.axes().get_yaxis().set_major_formatter(ticks_y)

plt.axes().locator_params(tight=True, nbins=4)

plt.xlabel('Latency (us)')
plt.ylabel('CDF')
plt.tight_layout()

leg = plt.legend(loc='lower right',
        fancybox=True, framealpha=0.5,
        numpoints=1, handlelength=0.5, handletextpad=0.2,
        labelspacing=0.2,
        prop={'size': fontsize})
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
plt.xlim([0,600])
plt.ylim([0.8,1.0])
plt.savefig('cdf_zoomed7.pdf')
plt.savefig('cdf_zoomed7.png', transparent=transparent_png)
plt.xlim([0,50])
plt.ylim([0.96,1.0])
leg.remove()
plt.savefig('cdf_zoomed8.pdf')
plt.savefig('cdf_zoomed8.png', transparent=transparent_png)
