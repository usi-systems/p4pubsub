#!/usr/bin/python
#
#  This file is part of Siena, a wide-area event notification system.
#  See http://www.inf.unisi.ch/carzaniga/siena/
#
#  Author: Antonio Carzaniga
#
#  Copyright (C) 2006,2009 Antonio Carzaniga
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License
#  as published by the Free Software Foundation; either version 2
#  of the License, or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307,
#  USA, or send email to one of the authors.
#
#
# $Id: ssbg.py,v 1.8 2017/09/06 16:11:53 carzanig Exp $
#
import random
import math
import sys

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
    "A Zipf probability distribution with exponent 1 over a range of numbers"
    def __init__(self, N):
	self.N = 0
	self.D = []
	for i in range(1, N):
	    self.N = self.N + N/i
	    self.D.append((self.N, i))

#
# predicate-generation function
#
def generate_predicate(filters_num_D, attr_num_D, attr_id_D, attributes):
    "\
Generates a predicate and prints it on stdout.  Parameters are as follows:\n\
id is the `interface' identifier;\n\
filters_num_D is the distribution of predicate sizes (in number of filters);\n\
constr_num_D is the distribution of filter sizes (in number of constraints);\n\
attr_id_D is the distribution of attribute names;\n\
attributes is a vector of attribute descriptors, each one with two elements:\n\
    [0] : distribution of constraints for this attribute\n\
    [1] : distribution of comparison values for this attribute\n\
"
    disj = []
    f_count = filters_num_D.pick_element()
    for i in range(0, f_count):
        conj = []
        a_count = attr_num_D.pick_element()
        # I could pick n elements with replacement, but this may cause
        # more trouble than not.  In fact, with tight distributions, I
        # might pick the most popular attribute twice, but then choose
        # two incompatible constraints (e.g., x1="ciao", x1="blah")
        # Therefore, I prefer to exclude the case of multiple
        # constraints on the same attribute, and pick n elements
        # without replacement.
        attribute_ids = attr_id_D.pick_n_elements(a_count)
        for a_id in attribute_ids:
            a_descr = attributes[a_id]
            conj.append( ('x' + repr(a_id), a_descr[0].pick_element(), str(a_descr[1].pick_element())) )

        disj.append(conj)

    return disj
#
# message-generation function
#
def generate_message(attr_num_D, attr_id_D, attributes):
    "\
Generates a message and prints it on stdout.  Parameters are as follows:\n\
attr_num_D is the distribution of message sizes (in number of attributes);\n\
attr_id_D is the distribution of attribute names;\n\
attributes is a vector of attribute descriptors, each one with two elements:\n\
    [0] : distribution of constraints for this attribute\n\
    [1] : distribution of comparison values for this attribute\n\
"
    a_count = attr_num_D.pick_element()
    attribute_ids = attr_id_D.pick_n_elements(a_count)
    conj = []
    for a_id in attribute_ids:
        a_descr = attributes[a_id]
        conj.append( ('x' + repr(a_id), str(a_descr[1].pick_element())) )
    return conj

# entry point method
def ssbg(attr_dist_type, attr_space_size, predicates_size, number_of_filters, number_of_messages):
    ############################################################################    
    #
    # This is where we define distributions for values, names, etc.
    #
    str_values = Distribution({ \
            'contract' : 24370, \
                'recent' : 24558, \
                'chang' : 24598, \
                'hous' : 24675, \
                'good' : 24761, \
                'fall' : 24848, \
                'numb' : 24878, \
                'ago' : 25055, \
                'vote' : 25119, \
                'rule' : 25216, \
                'system' : 25301, \
                'bid' : 25302, \
                'half' : 25348, \
                'americ' : 25481, \
                'august' : 25529, \
                'decemb' : 25590, \
                'polit' : 25679, \
                'show' : 25733, \
                'gain' : 25910, \
                'public' : 26026, \
                'announc' : 26403, \
                'made' : 26480, \
                'part' : 26658, \
                'york' : 26671, \
                'pow' : 26698, \
                'remain' : 26770, \
                'support' : 26875, \
                'aver' : 26959, \
                'memb' : 26989, \
                'nov' : 26996, \
                'demand' : 27146, \
                'talk' : 27444, \
                'import' : 27572, \
                'mark' : 27776, \
                'current' : 28032, \
                'earn' : 28105, \
                'strong' : 28266, \
                'develop' : 28421, \
                'forc' : 28457, \
                'london' : 28488, \
                'south' : 28666, \
                'capit' : 28827, \
                'rose' : 28932, \
                'decid' : 29177, \
                'start' : 29330, \
                'larg' : 29350, \
                'prim' : 29366, \
                'austral' : 29786, \
                'growth' : 30002, \
                'japan' : 30205, \
                'major' : 30501, \
                'new' : 30688, \
                'sell' : 30766, \
                'level' : 30813, \
                'direct' : 30901, \
                'cut' : 31105, \
                'cost' : 31249, \
                'reut' : 31423, \
                'long' : 31562, \
                'open' : 31664, \
                'novemb' : 31699, \
                'union' : 31726, \
                'back' : 31769, \
                'due' : 31885, \
                'futur' : 32074, \
                'export' : 32248, \
                'term' : 32911, \
                'oct' : 33149, \
                'hold' : 33211, \
                'move' : 33414, \
                'continu' : 33462, \
                'elect' : 33499, \
                'chin' : 33555, \
                'franc' : 33830, \
                'world' : 33983, \
                'manag' : 34029, \
                'set' : 34213, \
                'servic' : 34323, \
                'gener' : 34355, \
                'exchang' : 34507, \
                'forecast' : 34777, \
                'base' : 35109, \
                'corp' : 35381, \
                'index' : 35488, \
                'late' : 36306, \
                'peopl' : 36407, \
                'incom' : 36513, \
                'dollar' : 36714, \
                'rise' : 36966, \
                'party' : 37056, \
                'fund' : 37362, \
                'call' : 37828, \
                'busi' : 37842, \
                'octob' : 38027, \
                'note' : 38345, \
                'agree' : 38800, \
                'buy' : 38905, \
                'european' : 39147, \
                'work' : 39249, \
                'firm' : 39387, \
                'total' : 39481, \
                'polic' : 39675, \
                'result' : 39798, \
                'increas' : 40230, \
                'intern' : 40365, \
                'includ' : 40443, \
                'meet' : 40512, \
                'foreign' : 40551, \
                'quart' : 40845, \
                'yen' : 41397, \
                'secur' : 41853, \
                'anal' : 42248, \
                'make' : 42648, \
                'loss' : 43695, \
                'tax' : 43727, \
                'ton' : 44880, \
                'countr' : 44882, \
                'commit' : 45453, \
                'oil' : 45467, \
                'bond' : 45631, \
                'septemb' : 45779, \
                'interest' : 46064, \
                'monday' : 48500, \
                'told' : 48826, \
                'friday' : 49008, \
                'nation' : 49457, \
                'industr' : 49766, \
                'profit' : 50511, \
                'thursday' : 50610, \
                'point' : 50997, \
                'early' : 51035, \
                'add' : 51531, \
                'time' : 51655, \
                'wednesday' : 51965, \
                'tuesday' : 53065, \
                'issu' : 54649, \
                'financ' : 55676, \
                'unit' : 57042, \
                'operat' : 57211, \
                'lead' : 57337, \
                'presid' : 57407, \
                'plan' : 57419, \
                'low' : 57950, \
                'deal' : 58509, \
                'net' : 59540, \
                'newsroom' : 60614, \
                'group' : 60734, \
                'pct' : 62499, \
                'day' : 62721, \
                'invest' : 64709, \
                'clos' : 65764, \
                'econom' : 67127, \
                'stock' : 68228, \
                'sale' : 68551, \
                'produc' : 69071, \
                'report' : 69971, \
                'minist' : 70462, \
                'cent' : 77668, \
                'high' : 78053, \
                'expect' : 78952, \
                'week' : 79484, \
                'end' : 80109, \
                'offic' : 81926, \
                'billion' : 82718, \
                'govern' : 88262, \
                'rate' : 93466, \
                'month' : 96432, \
                'pric' : 108175, \
                'compan' : 114137, \
                'stat' : 118010, \
                'bank' : 122967, \
                'shar' : 137559, \
                'market' : 140363, \
                'trad' : 142435, \
                'million' : 191853, \
                'year' : 207127, \
                'percent' : 214479 \
                })
    
    int_ops = Distribution({ '='  : 50, \
                                 '<'  : 25, \
                                 '>'  : 25, \
                                 #'!=' : 10  \
                                 })

    str_ops = Distribution({ '='  : 1 })

    # TODO: uncomment this when we support negative values in Camus
    #int_values = Uniform(-100, 100)
    int_values = Uniform(0, 100)

    #
    # probability distribution for the type and values of constraints.
    # I.e., this is a distribution of pairs of the form
    #
    #  (operator_dist, value_dist)
    #
    # where the first element is a distribution of operators and the
    # second element is a distribution of comparison values.
    #
    attributes_dist = Distribution ({ (str_ops, str_values) : 50, \
                                          (int_ops, int_values) : 50  \
                                          })
    #
    # probability distribution for the number of constraints in a conjunction
    #
    constraint_counts = Distribution({ 1 : 10, \
                                           2 : 40, \
                                           3 : 30, \
                                           4 : 10, \
                                           5 : 5,  \
                                           6 : 5   \
                                           })
    #
    # probability distribution for the number of attributes in a message
    #
    attribute_counts = Distribution({ 1 : 5, \
                                          2 : 10, \
                                          3 : 10, \
                                          4 : 20, \
                                          5 : 20, \
                                          6 : 20, \
                                          7 : 10,  \
                                          8 : 5   \
                                          })
    #
    # here we build the attribute vector.  This vector associates an
    # attribute name, which is actually represented by a number, to a pair
    # (operator_dist, value_dist).  The idea is that the association is
    # fixed for the entire workload.  The rationale is that, for example,
    # the "price" attribute is always an integer constraint with such and
    # such distributions of constraints and values.
    #
    attributes = []
    for i in range(0, attr_space_size):
        attributes.append(attributes_dist.pick_element())
        
    if attr_dist_type == 'Z':
        attribute_ids = Zipf(attr_space_size)
    else:
        attribute_ids = Uniform(1,attr_space_size)
            
    #
    # probability distribution for the number of filters in a predicate
    #
    predicates = []
    for i in range(0, number_of_filters):
        predicates.append(generate_predicate(Poisson(predicates_size), constraint_counts, attribute_ids, attributes))
        
    messages = []
    for i in range(0, number_of_messages):
        messages.append(generate_message(attribute_counts, attribute_ids, attributes))

    return (predicates, messages)

if __name__ == '__main__':
    ############################################################################    
    #
    # "free" parameters of the workload.  These are passed to the
    # generator as command-line parameters.
    #
    if len(sys.argv) != 6 or (len(sys.argv) > 1 and sys.argv[1] == "--help"):
        print "usage: ", sys.argv[0], " Z|U <attr-space-size> <predicate-size> <predicates> <messages>\n\
parameters:\n\
    Z  select attributes using a Zipf probability distribution\n\
    U  select attributes using a uniform probability distribution\n\
    <attr-space-size>  total number of distinct attributes\n\
    <predicate-size>  average number of filters per predicate\n\
    <predicates>  number of generated predicates\n\
    <messages>  number of generated messages\n\
\n\
This program generates a number of predicate and/or a number of messages\n\
using the SFF syntax.  Each predicate is a disjunction of filters, where a\n\
filter is a conjunction of constraints.  Each constraint is defined\n\
by an attribute name, a selection operator, and a constant value.\n\
Each message is a set of attributes, each having a unique name and a value.\n\
\n\
Predicates and messages are generated by two simple algorithms parameterized\n\
by several random variables.  This program defines these two algorithms in\n\
generate_predicate() and generate_message(), respectively.\n\
The distributions for their parameters are defined in ssbg() in:\n\
str_values, int_values, int_ops, str_ops, attributes_dist, constraint_counts,\n\
and attribute_counts.\n\
Please, see the documentation within the code.\n\
"
        sys.exit(1)
    else:
        predicates, messages = ssbg(sys.argv[1],int(sys.argv[2]),int(sys.argv[3]),int(sys.argv[4]),int(sys.argv[5]))

        i = 0
        for p in predicates:
            i += 1

            dsep = ''
            for disjunction in p:
                sys.stdout.write(dsep)
                csep = ''
                for conjuction in disjunction:
                    sys.stdout.write(csep + conjuction[0] + ' ' + conjuction[1] + ' ' + conjuction[2])
                    csep = ' and '
                sys.stdout.write('\n')
                dsep = ' or '

            print ': %d;' % i

        for m in messages:
            sys.stdout.write('select ')

            csep = ''
            for c in m:
                sys.stdout.write(csep + c[0] + ' = ' + c[1])
                csep = '  '
            
            sys.stdout.write('\n')

