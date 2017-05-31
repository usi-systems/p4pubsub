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
import multiprocessing

#random.seed(1)

def bin2(n): return bin(n)[2:]
def int2(s): return int(s.replace(' ', ''), 2)

class BIER:

    def __init__(self, num_ports=16, mgid_bits=4, chunk_bits=None):
        self.num_ports = num_ports
        self.mgid_bits = mgid_bits
        self.chunk_bits = chunk_bits

        if self.chunk_bits is None:
            if num_ports % mgid_bits == 0 or num_ports-((num_ports/mgid_bits)*(mgid_bits-1)) < num_ports-(((num_ports/mgid_bits)-1)*(mgid_bits-1)):
                self.chunk_bits = num_ports/mgid_bits
            else:
                self.chunk_bits = (num_ports/mgid_bits)-1

        # The last chunk may be bigger or smaller:
        self.last_chunk_bits = num_ports - (self.chunk_bits *(mgid_bits-1))

        self.chunk_mask = [(2**self.chunk_bits)-1 for b in range(self.mgid_bits-1)]
        self.chunk_mask += [(2**self.last_chunk_bits)-1]

        #mgids = [i for i in range(0, 2**mgid_bits)]
        #mgid_to_bs = dict((mgid, self.get_bs(mgid)) for mgid in mgids)
        #fmt1, fmt2 = '{:0>%d}' % self.mgid_bits, '{:0>%d}' % self.num_ports
        #for mgid,bs in mgid_to_bs.iteritems(): print fmt1.format(bin2(mgid)), fmt2.format(bin2(bs))


    def get_bs(self, mgid):
        bs = 0
        for shift in range(0, self.mgid_bits):
            bs |= (((mgid >> shift) & 1) * self.chunk_mask[shift]) << shift*self.chunk_bits
        return bs

    def get_mgid(self, bs):
        mgid = 0
        for shift in range(0, self.mgid_bits):
            if ((bs >> shift*self.chunk_bits) & self.chunk_mask[shift]) > 0:
                mgid |= 1 << shift
        return mgid

    def select_random_not_in_table(self):
        while True:
            bs = random.randint(0, 2**self.num_ports)
            # check if bs is in the table:
            if self.get_bs(self.get_mgid(bs)) == bs: continue
            return bs

    def count_spurious(self, bs):
        mgid = self.get_mgid(bs) # this BS maps to this MGID
        all_ports = self.get_bs(mgid) # the BS for all the ports of this MGID
        diff = bs ^ all_ports
        return bin(diff).count('1')

    def select_and_count_spurious(self, total_bitstrings, fraction_not_in_table):
        n = int(total_bitstrings*fraction_not_in_table)
        spurious_count = 0
        for _ in range(n):
            bs = self.select_random_not_in_table()
            spurious_count += self.count_spurious(bs)
        return spurious_count


#bier_router = BIER(num_ports=16, mgid_bits=5)
#bs = bier_router.select_random_not_in_table()
#print bin2(bs)

#print bin2(bier_router.get_bs(int2('1')))
#print bin2(bier_router.get_mgid(int2('111000')))

N = 1 * 10**6

def runwith(x):
    num_ports = 256
    mgid_bits = 11
    bier_router = BIER(num_ports=num_ports, mgid_bits=mgid_bits)
    return (x, bier_router.select_and_count_spurious(N, x))

jobs = multiprocessing.cpu_count()
#xs = range(2, 12)
xs = [0.01*i for i in range(1, 25)]

if jobs > 1:
    p = multiprocessing.Pool(jobs)
    xy = p.map(runwith, xs)
else:
    xy = map(runwith, xs)

for x,y in xy:
    print "%f\t%d" % (x,y)
