# We want to have each of these identifiers map to a unique 16 bit string. We
# can just do the following:
#
# 0000 -> 0000 0000 0000 0000
# 0001 -> 0000 0000 0000 1111
# 0010 -> 0000 0000 1111 0000
# ....
# 0011 -> 0000 0000 1111 1111
#
# MGID -> bitstring (bs)
#


import random

random.seed(1)

num_ports = 16
mgid_bits = 4
chunk_bits = 4

def bin2(n):
    return bin(n)[2:]

mgids = [i for i in range(0, 2**mgid_bits)]

bits = (2**chunk_bits)-1 # 1111

def get_bs(mgid):
    bs = 0
    for shift in range(0, mgid_bits):
        bs |= (((mgid >> shift) & 1) * bits) << shift*chunk_bits
    return bs

mgid_to_bs = dict((mgid, get_bs(mgid)) for mgid in mgids)

#for mgid,bs in mgid_to_bs.iteritems(): print '%04s' % bin2(mgid), '%016s'%bin2(bs)

forwarding_table = dict((bs,mgid) for (mgid,bs) in mgid_to_bs.iteritems())

def select_random_not_in_table():
    while True:
        x = random.randint(0, 2**num_ports)
        if x in forwarding_table.keys(): continue
        return x

def select_random_in_table():
    return random.choice(forwarding_table.keys())

def get_mgid(bs):
    mgid = 0
    for shift in range(0, mgid_bits):
        if ((bs >> shift*chunk_bits) & bits) > 0:
            mgid |= 1 << shift
    return mgid

def count_spurious(bs):
    mgid = get_mgid(bs) # this BS maps to this MGID
    all_ports = get_bs(mgid) # the BS for all the ports of this MGID
    diff = bs ^ all_ports
    return bin(diff).count('1')



# Example of counting spurious packets:
#x = select_random_not_in_table()
x = int('1111 0010 1011 0000'.replace(' ', ''), 2)
print "BS", bin2(x), "maps to MGID", bin2(get_mgid(x))
print "Spurious packets", count_spurious(x)
