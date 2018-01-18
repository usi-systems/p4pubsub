#!/usr/bin/env python

# Plot one or more files on the same X axis

import sys
import matplotlib
import os
havedisplay = "DISPLAY" in os.environ
if not havedisplay:
    matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import itertools

filenames = sys.argv[1:]

#matplotlib.rcParams['ps.useafm'] = True
#matplotlib.rcParams['pdf.use14corefonts'] = True
#matplotlib.rcParams['text.usetex'] = True
#plt.rc('font',family='Times New Roman')
plt.style.use('ggplot')
#matplotlib.rcParams.update({'font.size': 16})
#matplotlib.rcParams.update({'font.weight': 'bold'})
#matplotlib.rcParams.update({'axes.labelweight': 'bold'})
matplotlib.rcParams.update({'text.color': 'black'})

markers = itertools.cycle(('o', '^', 'D', 's', '+', 'x', '*' ))
linestyles = itertools.cycle(("-","-.","--",":"))
colors = itertools.cycle(('r', 'g', 'b', 'c', 'm', 'y', 'k'))
hatches = itertools.cycle(('x', '/', 'o', '\\', '*', 'o', 'O', '.'))

formatLabel = lambda l: l.replace('_', '\\_') if matplotlib.rcParams['text.usetex'] else l

handles = []
labels = filenames
labels = ["Baseline", "Switch-Based Mitigation"]

fig, ax = plt.subplots()

xlabel = "Time (ms)"
ylabel = "Throughput (pps)"

ax.set_xlabel(formatLabel(xlabel))
ax.set_ylabel(formatLabel(ylabel))
ax.set_xlim([0, 600])
ax.set_ylim([0, 360000])

for i,filename in enumerate(filenames):
    #if i != 0: ax = ax.twinx() # For different y scales

    data = np.loadtxt(filename, unpack=True)

    h, = ax.plot(data[0], data[1], color=colors.next(),
            marker=None, linestyle=linestyles.next(),
            label=filename, linewidth=2)
    handles.append(h)


plt.legend(handles, labels, loc='upper left')

plt.savefig('out.pdf')
plt.show()
