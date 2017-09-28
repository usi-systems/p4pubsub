#!/usr/bin/env python

import sys
import argparse
from itch_message import AddOrderMessage
from probability_distributions import Distribution, Uniform, Zipf

MAX_INT = sys.maxint

class Tables:
    def __init__(self, rules):

        # tables:
        self.stock = {}
        self.shares = [MAX_INT]
        self.price = [MAX_INT]
        self.agg = {}

        self.rules = rules


    def _findLt(self, tbl, val):
        for i,b in enumerate(tbl):
            if b < val: yield i+1
            else: break

    def _findGt(self, tbl, val):
        for i,b in enumerate(tbl):
            if b > val: yield i+1
            else: break

    def _findRange(self, tbl, op, val):
        if op == '<':
            return list(self._findLt(tbl, val))
        elif op == '>':
            return list(self._findGt(tbl, val))
        else:
            assert False, "Bad range op: %s" % op

    def _addRange(self, tbl, op, val):
        if op == '<':
            bound = val-1
        elif op == '>':
            bound = val
        else:
            assert False, "Bad range op: %s" % op

        if bound not in tbl:
            tbl.append(bound)
            if op == '>': tbl.sort(reverse=True)
            else: tbl.sort()

    def _addStock(self, stock):
        if stock not in self.stock:
            self.stock[stock] = len(self.stock)+1

    def _addToAgg(self, predicate_list, port):
        stock_lbl = None
        price_lbls, shares_lbls = [], []

        for pred in predicate_list:
            field, op, val = pred

            if field == 'stock':
                stock_lbl = self.stock[val]
            elif field == 'shares':
                shares_lbls = self._findRange(self.shares, op, val)
            elif field == 'price':
                price_lbls = self._findRange(self.price, op, val)

        if len(price_lbls) == 0: price_lbls = [0]
        if len(shares_lbls) == 0: shares_lbls = [0]

        if stock_lbl not in self.agg: self.agg[stock_lbl] = {}

        for s in shares_lbls:
            if s not in self.agg[stock_lbl]:
                self.agg[stock_lbl][s] = {}
            for p in price_lbls:
                if p not in self.agg[stock_lbl][s]:
                    self.agg[stock_lbl][s][p] = []
                self.agg[stock_lbl][s][p].append(port)



    def _makeTableMatches(self, predicate_list):
        for pred in predicate_list:
            field, op, val = pred

            if field == 'stock':
                self._addStock(val)
            elif field == 'shares':
                self._addRange(self.shares, op, val)
            elif field == 'price':
                self._addRange(self.price, op, val)
            else:
                assert False, "bad field %s" % field

    def build(self):
        for query,_ in self.rules:
            self._makeTableMatches(query)

        for query,port in self.rules:
            self._addToAgg(query, port)

    def explodeAgg(self):
        for stock in self.agg:
            for shares in self.agg[stock]:
                for price, ports in self.agg[stock][shares].iteritems():
                    yield (stock, shares, price, ports)

    def lookup(self, query):
        pass





def pickDifferent(dist, val):
    val2 = dist.pick_element()
    while val2 == val:
        val2 = dist.pick_element()
    return val2

def predToStr(pred):
    field, op, val = pred
    val_str = '"%s"' % val if type(val) == str else '%d' % val
    return "%s%s%s" % (field, op, val_str)

def queryToStr(predicate_list):
    return ' and '.join(map(predToStr, predicate_list))

def generate_predicates(field, op_dist, value_dist):
    ops = op_dist.pick_element()

    if 'x' in ops: # do not generate any predicates for this field
        return []

    val = value_dist.pick_element()

    if '=' in ops:
        assert len(ops) == 1, "Cannot have eq together with other operators"
        return [(field, '=', val)]

    assert type(val) != str, "String only supports eq operator"

    if '<' in ops and '>' in ops:
        val2 = pickDifferent(value_dist, val)
        low, high = (val, val2) if val < val2 else (val2, val)
        return [(field, '>', low), (field, '<', high)]
    elif '<' in ops:
        return [(field, '<', val)]
    elif '>' in ops:
        return [(field, '>', val)]
    else:
        assert False, "Unrecognized operators: %s" % str(ops)

stock_symbols = [str(i) for i in range(1000)]

def generate_queries(count=1):

    stock_dist = Zipf(values=stock_symbols)
    price_dist_for_stock = dict()
    avg_price_dist = Uniform(10, 180)
    shares_dist = Uniform(1, 100)
    stock_op_dist = Distribution({ '=': 1 })
    price_op_dist = Distribution({
        'x': 0,
        '=': 0,
        '<': 40,
        '>': 40,
        '<>': 20
        })
    shares_op_dist = Distribution({
        'x': 65,
        '=': 0,
        '<': 15,
        '>': 15,
        '<>': 5
        })

    for _ in xrange(count):

        stock = stock_dist.pick_element()

        if stock not in price_dist_for_stock:
            avg = avg_price_dist.pick_element()
            std = int(avg*0.1)
            assert std > 0
            min_price, max_price = avg-std, avg+std
            price_dist_for_stock[stock] = Uniform(min_price, max_price)

        price_preds = generate_predicates('price',
                                    price_op_dist,
                                    price_dist_for_stock[stock])
        shares_preds = generate_predicates('shares',
                                    shares_op_dist,
                                    shares_dist)

        yield [('stock', '=', stock)] + price_preds + shares_preds

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Generate a dump of ITCH messages')
    parser.add_argument('--count', '-c', help='Number of queries to generate',
            type=int, default=2)
    parser.add_argument('--ports', '-p', help='Number of ports',
            type=int, default=32)
    parser.add_argument('--stats', '-s', help='Print stats',
            action='store_true', default=False)
    parser.add_argument('--fields', '-f', help='Field values. E.g. StockLocate=1,Price=33',
            type=lambda s: dict(f.split('=') for f in s.split(',')), default=dict())
    args = parser.parse_args()


    rules = []
    for i,q in enumerate(generate_queries(count=args.count)):
        port = (i % args.ports) + 1
        rules.append((q, port))
        print "%-65s: %d;" % (queryToStr(q), port)

    tbls = Tables(rules)
    tbls.build()
    if args.stats:
        print "stock:", len(tbls.stock)
        print "shares:", len(tbls.shares)
        print "price:", len(tbls.price)
        print "agg:", len(list(tbls.explodeAgg()))
