from p4app import P4Mininet
from mininet.topo import SingleSwitchTopo
from itertools import combinations

MAX_PORTS = 5
MAX_X, MAX_Y = 20, 20
TILE_SIZE = 10
N = 3

topo = SingleSwitchTopo(N)
net = P4Mininet(program='dynsub.p4', topo=topo)
net.start()

s1 = net.get('s1')

for i in range(1, N+1):
    h = net.get('h%d' % i)
    s1.insertTableEntry(table_name='MyIngress.ipv4_lpm',
                        action_name='MyIngress.ipv4_forward',
                        match_fields={'hdr.ipv4.dstAddr': [h.intfs[0].ip, 32]},
                        action_params={'dstAddr': h.intfs[0].mac,
                                          'port': i})

i = 0
for x in range(0, MAX_X, TILE_SIZE):
    for y in range(0, MAX_Y, TILE_SIZE):
        i += 1
        x1, x2, y1, y2 = x, x+(TILE_SIZE-1), y, y+(TILE_SIZE-1)
        #print "%02d,%02d  %02d,%02d  -> set_tile_id %02d" % (x1, x2, y1, y2, i)
        s1.insertTableEntry(table_name='MyIngress.grid',
                            match_fields={'hdr.pos.x': [x1, x2],
                                          'hdr.pos.y': [y1, y2]},
                            priority=i,
                            action_name='MyIngress.set_tile_id',
                            action_params={'tile_id': i})

ports = range(1, MAX_PORTS+1)
port_sets = sum([list(combinations(ports, i)) for i in range(1, len(ports)+1)], [])
print "len port_sets", len(port_sets) #, "\n", port_sets

def make_pmap(pset):
    return reduce(lambda a,b: a|b, [1 << (p-1) for p in pset], 0)

for i,pset in enumerate(port_sets):
    if i > 885:
        raise Exception("Too many mcast groups!")
    pmap = make_pmap(pset)
    mgid = i+1
    s1.addMulticastGroup(mgid=mgid, ports=pset)
    s1.insertTableEntry(table_name='MyIngress.portmap_to_mgid',
                        match_fields={'meta.meta.portmap': [pmap, 0xffffffff]},
                        priority=1,
                        action_name='MyIngress.set_mgid',
                        action_params={'mgid': mgid})

h1, h2, h3 = net.get('h1'), net.get('h2'), net.get('h3')

print h2.cmd('./client.py 2 10.0.0.1 5 5')
print h1.cmd('./control.py 10.0.0.255 2')
print h3.cmd('./client.py 3 10.0.0.1 5 5')
print h1.cmd('./control.py 10.0.0.255 2')
print h3.cmd('./client.py 3 10.0.0.1 5 5')

print "OK"
