#!/usr/bin/env python

import sys
import struct
import argparse
import math
import random
from itch_message import AddOrderMessage


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
        N = N if values is None else len(values)
	self.N = 0
	self.D = []
	for i in range(1, N):
            self.N = self.N + N/i
            v = i if values is None else values[i]
            self.D.append((self.N, v))

def pickDifferent(dist, val):
    val2 = dist.pick_element()
    while val2 == val:
        val2 = dist.pick_element()
    return val2

class FieldPredicateSetGenerator:

    def __init__(self, field, value_dist, op_dist):
        self.field = field
        self.value_dist = value_dist
        self.op_dist = op_dist

    def gen(self):
        ops = self.op_dist.pick_element()

        if 'x' in ops: # do not generate any predicates for this field
            return []

        val = self.value_dist.pick_element()

        if '=' in ops:
            assert len(ops) == 1, "Cannot have eq together with other operators"
            val_str = '"%s"' % val if type(val) == str else '%d' % val
            return ['%s=%s' % (self.field, val_str)]

        assert type(val) != str, "String only supports eq operator"

        if '<' in ops and '>' in ops:
            val2 = pickDifferent(self.value_dist, val)
            low, high = (val, val2) if val < val2 else (val2, val)
            return ['%s>%d' % (self.field, low), '%s<%d' % (self.field, high)]
        elif '<' in ops:
            return ['%s<%d' % (self.field, val)]
        elif '>' in ops:
            return ['%s>%d' % (self.field, val)]
        else:
            assert False, "Unrecognized operators: %s" % str(ops)


def generate_query(predicate_generators):
    predicates = []

    while len(predicates) == 0:
        for generator in predicate_generators:
            predicates += generator.gen()

    return ' and '.join(predicates)

stock_symbols = [str(i) for i in range(100)]

def generate_queries(count=1):
    num_val_dist = Uniform(0, 100)

    str_val_dist = Zipf(values=stock_symbols)

    price_op_dist = Distribution({
        'x': 1, # x means don't use this field at all
        '=': 1,
        '<': 1,
        '>': 1,
        '<>': 1
        })
    shares_op_dist = price_op_dist
    str_op_dist = Distribution({
        'x': 0, # x means don't use this field at all
        '=': 1
        })

    stock_generator = FieldPredicateSetGenerator('stock', str_val_dist, str_op_dist)
    price_generator = FieldPredicateSetGenerator('price', num_val_dist, price_op_dist)
    shares_generator = FieldPredicateSetGenerator('shares', num_val_dist, shares_op_dist)

    predicate_generators = [stock_generator, price_generator, shares_generator]


    return [generate_query(predicate_generators) for _ in xrange(count)]

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Generate a dump of ITCH messages')
    parser.add_argument('--count', '-c', help='Number of queries to generate',
            type=int, default=2)
    parser.add_argument('--fields', '-f', help='Field values. E.g. StockLocate=1,Price=33',
            type=lambda s: dict(f.split('=') for f in s.split(',')), default=dict())
    args = parser.parse_args()

    for q in generate_queries(count=args.count):
        print q
