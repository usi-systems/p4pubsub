
n = 0
for stock in range(100):
    for share in range(1000):
    #for share in reversed(range(1000)):
        n += 1
        #print "add_order.stock = %d and add_order.shares > %d: fwd(%d);" % (stock, share, n)
        print "add_order.stock = %d and add_order.shares > %d: fwd(%d);" % (stock, share, (n%200)+1)
        #print "add_order.stock = %d and add_order.shares = %d: fwd(1);" % (stock, share)
