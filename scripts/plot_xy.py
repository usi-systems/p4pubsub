#!/usr/bin/env python

# Plot one or more files on the same X axis

import sys
import numpy as np
import matplotlib.pyplot as plt

filenames = sys.argv[1:]

colors = ['g', 'r', 'b', 'c', 'o']
color_idx = -1
def nextColor():
    global color_idx
    color_idx = (color_idx + 1) % len(colors)
    return colors[color_idx]

handles = []
labels = []

fig, ax = plt.subplots()

for i,filename in enumerate(filenames):
    data = np.loadtxt(filename, unpack=True)

    h, = ax.plot(data[0], data[1], color=nextColor(), marker=None, label=filename)
    handles.append(h)
    labels.append(h.get_label())

    if i+1 < len(filenames):
        ax = ax.twinx()

plt.legend(handles, labels, loc='upper right')

plt.show()
