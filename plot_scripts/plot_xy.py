#!/usr/bin/env python

import sys
import numpy as np
import matplotlib.pyplot as plt

filename = sys.argv[1]

data = np.loadtxt(filename, unpack=True)

plt.plot(data[0], data[1], marker=None)

plt.show()
