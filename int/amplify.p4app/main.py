from p4app import P4Mininet, P4Program
from single_switch_topo import SingleSwitchTopo
import time
import sys

def mkMcNode(sw, ports):
    out = sw.command('mc_node_create 1 ' + ' '.join(map(str, ports)))
    return int(out.split()[-1])

topo = SingleSwitchTopo(3)
prog = P4Program('int-amp.p4', version=14)
net = P4Mininet(program=prog, topo=topo)
net.start()

s1 = net.get('s1')

s1.command('mc_mgrp_create 1')
node_handle = mkMcNode(s1, [1, 3])
s1.command('mc_node_associate 1 %d' % node_handle)

s1.commands(['table_set_default forward set_mgid 1',
             'table_add forward set_egress_port 1 => 3',
             'table_add from_loopback modify_int 1 =>',
             'table_add rewrite_dst set_dst 1 => 00:00:00:00:00:01 10.0.0.1',
             'table_add rewrite_dst set_dst 2 => 00:00:00:00:00:02 10.0.0.2',
             'table_add rewrite_dst set_dst 3 => 00:00:00:00:00:03 10.0.0.3',
             ])

h1 = net.get('h1') # loopback
h2 = net.get('h2') # int source
h3 = net.get('h3') # int sink

# Start the echo process on h1 to emulate a loopback port:
echo_proc = h1.popen('./loopback_echo.py 1234 10.0.0.3', stdout=sys.stdout)

# Start the sink and wait for it to be ready
sink_proc = h3.popen('./int-receiver -op 1234', stdout=sys.stdout)
time.sleep(0.2)

# Send some INT packets:
source_proc = h2.popen('./int-sender -c 1 -r 3 10.0.0.3 1234')
print source_proc.communicate()

time.sleep(0.2)

#raw_input() # debug

# Cleanup:
echo_proc.kill()
sink_proc.kill()
print echo_proc.communicate()
print sink_proc.communicate()
