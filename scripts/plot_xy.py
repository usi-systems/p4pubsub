#!/usr/bin/env python

# Plot one or more files on the same X axis

import sys
import matplotlib
import os
havedisplay = "DISPLAY" in os.environ
if not havedisplay:
    matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import numpy as np
import itertools

filenames = sys.argv[1:]

#matplotlib.rcParams['ps.useafm'] = True
#matplotlib.rcParams['pdf.use14corefonts'] = True
#matplotlib.rcParams['text.usetex'] = True
#plt.rc('font',family='Times New Roman')
#plt.style.use('ggplot')
matplotlib.rcParams.update({'font.size': 16})
matplotlib.rcParams.update({'font.weight': 'bold'})
matplotlib.rcParams.update({'axes.labelweight': 'bold'})
matplotlib.rcParams.update({'text.color': 'black'})
matplotlib.rcParams.update({'figure.figsize': [12, 4]})

markers = itertools.cycle(('o', '^', 'D', 's', '+', 'x', '*' ))
#linestyles = itertools.cycle(("-","-.","--",":"))
linestyles = itertools.cycle(("-"))
colors = itertools.cycle(('r', 'g', 'b', 'c', 'm', 'y', 'k'))
hatches = itertools.cycle(('x', '/', 'o', '\\', '*', 'o', 'O', '.'))

formatLabel = lambda l: l.replace('_', '\\_') if matplotlib.rcParams['text.usetex'] else l

handles = []
labels = filenames
labels = ["Baseline", "Switch-Based Mitigation"]

fig, ax = plt.subplots()

ax.grid()

for i,filename in enumerate(filenames):
    #if i != 0: ax = ax.twinx() # For different y scales
    color = colors.next()
    linestyle = linestyles.next()

    #data = np.loadtxt(filename, unpack=True)
    data = np.genfromtxt(filename, dtype=None, delimiter='\t')

    # Line of best fit
    xs, ys = zip(*data)[:2]
    #min_x, max_x, min_y, max_y = min(xs), max(xs), min(ys), max(ys)
    #ax.plot(np.unique(xs), np.poly1d(np.polyfit(xs, ys, 1))(np.unique(xs)), color=color, linestyle=linestyle)
    #from scipy.stats.stats import pearsonr
    #print pearsonr(xs, ys)

    h, = ax.plot(xs, ys, color=color, linestyle=linestyle,
            #marker=None,
            marker=markers.next(),
            label=filename, linewidth=0)

    handles.append(h)


#leg = plt.legend(handles, labels, loc='lower right')
#leg = plt.legend(handles, labels, loc='upper left')
#leg.get_frame().set_alpha(0.0)
#leg.get_frame().set_linewidth(0.0)

xlabel = "Time (ms)"
ylabel = "Throughput (Kpps)"

#ax.set_xlabel(formatLabel(xlabel))
#ax.set_ylabel(formatLabel(ylabel))
#ax.set_xlim([0, 500])
#ax.set_ylim([100000, 350000])

#scale = 1/1000.
#ticks = ticker.FuncFormatter(lambda y, pos: '{0:g}'.format(y*scale))
#ax.yaxis.set_major_formatter(ticks)

plt.tight_layout()
plt.savefig('out.pdf')
plt.show()
