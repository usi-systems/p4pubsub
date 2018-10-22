import matplotlib.pyplot as plt
import numpy as np
import sys

filename = sys.argv[-1]

data = []
with (sys.stdin if filename == '-' else open(filename, 'r')) as f:
    data = map(float, f.readlines())


plt.hist(data, normed=True, bins=30)
plt.ylabel('Histogram');

plt.show()
