import networkx as nx
import random

class Packet(dict):
    def __init__(self, src, dst):
        dict.__init__(self)
        self['src'] = src
        self['dst'] = dst



def genPortMap(topo):
    # the 0 (zero) port maps back to us
    return dict((v, dict((v2,i) for i,v2 in enumerate([v]+sorted(nx.neighbors(topo, v))))) for v in topo.nodes_iter())

