#!/usr/bin/env python
# Calculate average and std for numbers on stdin
import sys, os
import numpy as np

plot_hist = False
if len(sys.argv) > 1:
    if sys.argv[1] == '-p':
        plot_hist = True

xlabel = ''
if len(sys.argv) > 2: xlabel = sys.argv[2]

nums = np.genfromtxt(sys.stdin)
print "N=", len(nums)
print "%.2f +/- %.2f" % (np.mean(nums), np.std(nums))
p99 = np.percentile(nums, 99)
print "p50: {}, p99: {}".format(np.percentile(nums, 50), p99)

# Plot Histogram on x
if plot_hist:
    import matplotlib
    havedisplay = "DISPLAY" in os.environ
    if not havedisplay:
        matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    plt.rcParams.update({'figure.figsize':(7,5), 'figure.dpi':100})
    plt.hist(nums[nums < p99*1.01], bins=100)
    plt.gca().set(title='Frequency Histogram', ylabel='Frequency', xlabel=xlabel)
    plt.xlim([min(nums)*0.95, p99*1.01])
    plt.savefig("hist.png")
    if havedisplay:
        plt.show()
