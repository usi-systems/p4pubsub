import math
import random

# These distributions are from Antonio's ssbg.py

#
# First, I'm going to define some "distributions".  A distribution is
# an object out of which you can pick elements.
#
class BasicDistribution:
    "A generic probability distribution"
    def pick_n_elements(self, n):
        'pick n elements without replacement'
	r = [];
	if n < len(self.D):
            while n > 0:
                elem = self.pick_element();
                if elem not in r:
                    r.append(elem)
                    n = n - 1
        else:
            for k, v in self.D:
		r.append(v)
	return r

class Poisson(BasicDistribution):
    "A generic probability distribution"
    def __init__(self, lmbda):
        self.L = math.exp(-lmbda)

    def pick_element(self):
        k = 0
        p = 1
	while True:
            p = p * random.uniform(0,1)
            if p < self.L:
                return k
            k = k + 1

class Distribution(BasicDistribution):
    "A generic probability distribution created from a dictionary"
    def __init__(self, dset):
	"Creates a distribution starting from a dictionary.\
	The keys in the dictionary are the elements of the distribution, \
	while the values are the weights.  So, for every element (x : val) \
	in the dictionary, the probability D(x) is \
	val/sum(v, for all values v)"
	self.D = []
	self.N = 0
	for k, v in dset.iteritems():
            self.D.append((self.N, k))
            self.N = self.N + v

    def pick_element(self):
	r = random.uniform(0, self.N)
	i = 0
	m = 0
	j = len(self.D)
        while i < j:
            m = i + (j - i)/2
            if self.D[m][0] > r:
                j = m
            elif m + 1 < len(self.D) and self.D[m + 1][0] < r:
                i = m
            else:
                return self.D[m][1]
	return self.D[i][1]

    def __str__(self):
        res = '{'
        prev = 0
        for x in self.D:
            if x[0] > 0:
                res = res + str(1.0*(x[0] - prev)/self.N) + ')'
            res = res + '(' + str(x[1]) + ':'
            prev = x[0]
        res = res + str(1.0*(self.N - prev)/self.N) + ')}'
        return res

class Uniform(Distribution):
    "A uniform probability distribution over a range of numbers"
    def __init__(self, l, h):
	self.min = l
	self.max = h

    def pick_element(self):
	return int(random.randrange(self.min, self.max))

    def pick_n_elements(self, n):
	r = [];
	if n < self.max - self.min:
            while n > 0:
                elem = self.pick_element();
                if elem not in r:
                    r.append(elem)
                    n = n - 1
        else:
            for v in range(self.min, self.max):
		r.append(v)
	return r

class Zipf(Distribution):
    "A Zipf probability distribution with exponent 1 over a range of values or numbers"
    def __init__(self, N=None, values=None):
        if values is None: values = range(1, N+1)
        N = len(values)
	self.N = 0
	self.D = []
	for i,v in enumerate(reversed(values)):
            p = self.N + N/(i+1)
            self.D.append((p, v))
            self.N += p

if __name__ == '__main__':

    vals = ['a', 'b', 'c']
    dist = Zipf(values=vals)
    l = [dist.pick_element() for _ in xrange(1000)]

    for v in vals: assert v in l
