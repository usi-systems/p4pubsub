import sys
import numpy as np

count = int(sys.argv[-1])

n = 0
for stock in range(100):
    for share in range(1000):
        n += 1
        stock = np.random.randint(1, 101)
        share = np.random.randint(1, 1001)
        host = np.random.randint(1, 201)
        print "add_order.stock = %d and add_order.shares > %d: fwd(%d);" % (stock, share, host)
        if n == count: break
    if n == count: break
