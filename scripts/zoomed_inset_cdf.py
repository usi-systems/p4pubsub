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
matplotlib.rcParams.update({'font.size': 16})
matplotlib.rcParams.update({'font.weight': 'bold'})
matplotlib.rcParams.update({'axes.labelweight': 'bold'})
matplotlib.rcParams.update({'text.color': 'black'})


filenames = sys.argv[1::2]
labels = sys.argv[2::2]
assert len(filenames) == len(labels)

cdfs = {}

def mk_cdf(label, filename):
    data = np.loadtxt(filename)
    data = [x / 1000 for x in data]
    sorted_data = np.sort(data)
    yvals=np.arange(len(sorted_data))/float(len(sorted_data)-1)
    cdfs[label] = (sorted_data, yvals)

threads = [Thread(target=mk_cdf, args=(lbl, fn)) for lbl,fn in zip(labels, filenames)]
for t in threads: t.start()
for t in threads: t.join()

colors = cycle(['r', 'g', 'b', 'c', 'y', 'k', 'm'])
#linestyles = cycle(("-","-.","--",":"))
linestyles = cycle(("-"))

lbl_styles = {}

for lbl in labels:
    xs, ys = cdfs[lbl]
    linestyle, color, linewidth = next(linestyles), next(colors), 3
    lbl_styles[lbl] = (linestyle, color, linewidth)
    plt.plot(xs, ys, label=lbl, linestyle=linestyle, color=color, linewidth=linewidth)


# Display grid
plt.axes().grid()


# change unit of x axis
scale_x = 1
ticks_x = ticker.FuncFormatter(lambda x, pos: '{0:,g}'.format(x/scale_x).replace('+0', ''))
plt.axes().get_xaxis().set_major_formatter(ticks_x)
plt.axes().get_xaxis().set_ticks([0, 1e6, 2e6, 3e6, 4e6])

plt.xlabel('Message Inter-Arrival Time (us)')
plt.ylabel('CDF')
plt.tight_layout()


#leg = plt.legend(loc='lower right')
#leg.get_frame().set_alpha(0.0)
#leg.get_frame().set_linewidth(0.0)

transparent_png = False
plt.xlim([0,4e6])

from mpl_toolkits.axes_grid1.inset_locator import zoomed_inset_axes, inset_axes
ax = plt.axes()
#axins = zoomed_inset_axes(ax, 100.0, loc=4)
axins = inset_axes(ax, 4,4 , loc=4, bbox_to_anchor=(0.93, 0.19), bbox_transform=ax.figure.transFigure) # no zoom

for lbl in labels:
    xs, ys = cdfs[lbl]
    linestyle, color, linewidth = lbl_styles[lbl]
    axins.plot(xs, ys, label=lbl, linestyle=linestyle, color=color, linewidth=linewidth)

#axins.get_xaxis().set_ticks()
show_ticks = [0, 2e3, 4e3, 6e3, 8e3]
ticks_x = ticker.FuncFormatter(lambda x, pos: '{0:,g}'.format(x/scale_x) if x in show_ticks else '')
axins.get_xaxis().set_major_formatter(ticks_x)
axins.grid()

x1, x2, y1, y2 = 0, 8e3, 0.2, 0.60 # specify the limits
axins.set_xlim(x1, x2) # apply the x-limits
axins.set_ylim(y1, y2) # apply the y-limits

from mpl_toolkits.axes_grid1.inset_locator import mark_inset
mark_inset(ax, axins, loc1=2, loc2=3, fc="none", ec="0.3")

plt.yticks(visible=False)
#plt.xticks(visible=False)

plt.savefig('cdf.png', transparent=transparent_png)
plt.savefig('cdf.pdf')
plt.show()

# Zoom in
plt.xlim([0,500000])
plt.savefig('cdf_zoomed0.png', transparent=transparent_png)
plt.xlim([0,300000])
plt.savefig('cdf_zoomed1.pdf')
plt.savefig('cdf_zoomed1.png', transparent=transparent_png)
plt.xlim([0,400000])
plt.savefig('cdf_zoomed2.pdf')
plt.xlim([0,150000])
plt.savefig('cdf_zoomed2.png', transparent=transparent_png)
plt.xlim([0,100000])
plt.savefig('cdf_zoomed3.pdf')
plt.savefig('cdf_zoomed3.png', transparent=transparent_png)
plt.xlim([0,10000])
plt.savefig('cdf_zoomed4.png', transparent=transparent_png)
plt.xlim([0,700000])
plt.ylim([0.8,1.0])
plt.savefig('cdf_zoomed5.pdf')
plt.savefig('cdf_zoomed5.png', transparent=transparent_png)
