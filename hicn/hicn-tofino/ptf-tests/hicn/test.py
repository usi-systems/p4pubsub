# Copyright 2013-present Barefoot Networks, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Thrift PD interface basic tests
"""

import time
import sys
import logging
import socket
import struct

import unittest
import random
import threading
import time
import crcmod
import json
import ipaddr

import pd_base_tests

from ptf import config
from ptf.testutils import *
from ptf.thriftutils import *
from ptf import mask

import os

from hicn.p4_pd_rpc.ttypes import *
from mirror_pd_rpc.ttypes import *
from res_pd_rpc.ttypes import *
from pal_rpc.ttypes import *

from camus import CamusCompiler

this_dir = os.path.dirname(os.path.abspath(__file__))

dev_id = 0
dev_tgt = DevTarget_t(dev_id, hex_to_i16(0xFFFF))

def make_port(pipe, local_port):
    assert pipe >= 0 and pipe < 4
    assert local_port >= 0 and local_port < 72
    return pipe << 7 | local_port
def port_to_pipe(port):
    return port >> 7
def port_to_pipe_local_id(port):
    return port & 0x7F
def port_to_bit_idx(port):
    pipe = port_to_pipe(port)
    index = port_to_pipe_local_id(port)
    return 72 * pipe + index
def set_port_or_lag_bitmap(bit_map_size, indicies):
    bit_map = [0] * ((bit_map_size+7)/8)
    for i in indicies:
        index = port_to_bit_idx(i)
        bit_map[index/8] = (bit_map[index/8] | (1 << (index%8))) & 0xFF
    return bytes_to_string(bit_map)

def front_panel_to_dev(test, dev_id, fp="1/0"):
    (front_port, front_chnl) = fp.split("/")
    return test.pal.pal_port_front_panel_port_to_dev_port_get(
        dev_id,
        int(front_port),
        int(front_chnl))

def mirror_session(mir_type, mir_dir, sid, egr_port=0, egr_port_v=False,
                   egr_port_queue=0, packet_color=0, mcast_grp_a=0,
                   mcast_grp_a_v=False, mcast_grp_b=0, mcast_grp_b_v=False,
                   max_pkt_len=0, level1_mcast_hash=0, level2_mcast_hash=0,
                   cos=0, c2c=0, extract_len=0, timeout=0, int_hdr=[]):
  return MirrorSessionInfo_t(mir_type,
                             mir_dir,
                             sid,
                             egr_port,
                             egr_port_v,
                             egr_port_queue,
                             packet_color,
                             mcast_grp_a,
                             mcast_grp_a_v,
                             mcast_grp_b,
                             mcast_grp_b_v,
                             max_pkt_len,
                             level1_mcast_hash,
                             level2_mcast_hash,
                             cos,
                             c2c,
                             extract_len,
                             timeout,
                             int_hdr,
                             len(int_hdr))


class BaseTest(pd_base_tests.ThriftInterfaceDataPlane):
    def __init__(self):
        pd_base_tests.ThriftInterfaceDataPlane.__init__(self, ["hicn"])

        if test_param_get('target') == 'asic-model': # running on harlyn
            self.ingress_port = 0
            self.egress_port = 4
        else:
            self.ingress_port = 46
            self.egress_port =  52

        self.mirror_sessions = []
        self.loopback_ports = []

        self.mcast_groups = {}
        self.mc_hdls = {}
        self.mc_sess_hdl = None

        self.camus_rules = []
        self.camus_entries = []

        self.camus_spec_file = os.path.join(this_dir, "spec.p4")
        self.camus_rules_file = os.path.join(this_dir, "rules.txt")
        self.camus_compiler = CamusCompiler(self.camus_spec_file)

        # rewrite ethernet.dstAddr when sending to these ports:
        self.mac_tbl = {
                168: '0c:c4:7a:a3:25:d1',
                36: '0c:c4:7a:a3:25:c8'
                }


    def setUp(self):
        pd_base_tests.ThriftInterfaceDataPlane.setUp(self)

        self.shdl = self.conn_mgr.client_init()
        self.dev      = 0
        self.dev_tgt  = DevTarget_t(self.dev, hex_to_i16(0xFFFF))

        self.entries = {}
        self.default_entries = {}

        print("\nConnected to Device %d, Session %d" % (
            self.dev, self.shdl))

    def clearTable(self, table):
        delete_func = "self.client." + table + "_table_delete"
        while len(self.entries[table]):
            entry = self.entries[table].pop()
            exec delete_func + "(self.shdl, self.dev, entry)"

    def clearTables(self):
        for table in self.entries.keys():
            self.clearTable(table)
        self.entries = {}
        self.conn_mgr.complete_operations(self.shdl)

    def tearDown(self):
        try:
            if len(self.entries): print("Clearing table entries")
            for table in self.entries.keys():
                self.clearTable(table)
            if len(self.mirror_sessions): print("Removing mirror sessions")
            for h in self.mirror_sessions:
                self.mirror.mirror_session_delete(self.shdl, self.dev_tgt, h)
            if len(self.loopback_ports): print("Removing loopback ports")
            for port in self.loopback_ports:
                self.pal.pal_port_loopback_mode_set(dev_tgt.dev_id, port,
                                        pal_loopback_mod_t.BF_LPBK_NONE)
            self.teardownMulticast()
        except:
            print("Error while cleaning up. ")
            print("You might need to restart the driver")
        finally:
            self.conn_mgr.complete_operations(self.shdl)
            self.conn_mgr.client_cleanup(self.shdl)
            print("Closed Session %d" % self.shdl)
            pd_base_tests.ThriftInterfaceDataPlane.tearDown(self)

    def importCamusEntries(self, entries_file):
        with open(entries_file, 'r') as f:
            self.camus_entries = json.load(f)

    def importCamusRules(self, rules_file):
        self.camus_rules = []
        with open(rules_file, 'r') as f:
            for l in f:
                l = l.strip()
                if len(l) == 0: continue
                if l[0] == '#': continue
                self.camus_rules.append(l)

    def popTables(self):

        self.entries['rewrite_dmac'] = []
        for port,dmac in self.mac_tbl.iteritems():
            self.entries['rewrite_dmac'].append(
                    self.client.rewrite_dmac_table_add_with_set_dmac(self.shdl, self.dev_tgt,
                        hicn_rewrite_dmac_match_spec_t(hex_to_i16(port)),
                        hicn_set_dmac_action_spec_t(macAddr_to_string(dmac))))
            print "port %d => set_dmac(%s)" % (port, dmac)


        # Debug
        #egr_port = 52
        #self.client.query_actions_set_default_action_set_egress_port(self.shdl, self.dev_tgt,
        #        hicn_set_egress_port_action_spec_t(egr_port))
        #print "Default action: set_egress_port(%d)" % egr_port

        yellow_bps = 1
        red_bps    = 10000
        bytes_meter_spec = hicn_bytes_meter_spec_t(yellow_bps, 2, red_bps, 10, False)

        def getmatches(d):
            matches = []
            field_val = [(k.split('.')[-1], v) for k,v in d.iteritems()]
            for k,v in field_val:
                if k == 'state': matches = map(hex_to_byte, v) + matches
                elif v[0] > 2**32:
                    ip = ipaddr.IPv6Address(v[0])
                    matches += [ipv6Addr_to_string(str(ip))] + map(hex_to_i16, v[1:])
                else: matches += map(hex_to_i16, v)
            return matches

        for e in self.camus_entries:
            if not e: continue
            table_name = e['table_name'].split('.')[-1]
            act_name = e['action_name'].split('.')[-1]
            matches = getmatches(e['match_fields'])
            table_add = getattr(self.client, '%s_table_add_with_%s' % (table_name, act_name))
            match_spec = globals()['hicn_%s_match_spec_t' % table_name]

            if 'action_params' in e:
                act_spec = globals()['hicn_%s_action_spec_t' % act_name]
                assert len(e['action_params']) == 1
                param = e['action_params'].values()[0]
                args = [self.shdl, self.dev_tgt, match_spec(*matches)]

                if 'priority' in e:
                    priority = hex_to_i16(e['priority'])
                    print table_name, matches, priority, act_name, param
                    args.append(priority)
                else:
                    print table_name, matches, act_name, param

                args.append(act_spec(param))

                if table_name == 'query_ipv6_dstAddr_lpm': # hack
                    args.append(bytes_meter_spec)

                entry = table_add(*args)
            else:
                print table_name, matches, act_name
                entry = table_add(self.shdl, self.dev_tgt, match_spec(*matches))

            if table_name not in self.entries: self.entries[table_name] = []
            self.entries[table_name].append(entry)


    def setupMulticast(self):

        if self.mc_sess_hdl is None:
            self.mc_sess_hdl = self.mc.mc_create_session()

        for mgid, ports in self.mcast_groups.items():
            if len(ports) < 2: continue
            rid = 1
            lag_map = set_port_or_lag_bitmap(256, [])

            port_map = set_port_or_lag_bitmap(288, ports)
            mc_node_hdl = self.mc.mc_node_create(self.mc_sess_hdl, dev_id, rid, port_map, lag_map)

            mc_grp_hdl = self.mc.mc_mgrp_create(self.mc_sess_hdl,
                                                        dev_id,
                                                        mgid)
            self.mc.mc_associate_node(self.mc_sess_hdl, dev_id, mc_grp_hdl,
                                      mc_node_hdl, 0, 0)

            self.mc_hdls[mgid] = (mc_node_hdl, mc_grp_hdl)

            self.mc.mc_complete_operations(self.mc_sess_hdl)

            print "mgid", mgid, "=>", ports

    def clearMulticast(self):
        for mc_node_hdl,mc_grp_hdl in self.mc_hdls.values():
            self.mc.mc_dissociate_node(self.mc_sess_hdl, dev_id, mc_grp_hdl, mc_node_hdl)
            self.mc.mc_mgrp_destroy(self.mc_sess_hdl, dev_id, mc_grp_hdl)
            self.mc.mc_node_destroy(self.mc_sess_hdl, dev_id, mc_node_hdl)
        self.mc_hdls = {}

    def teardownMulticast(self):
        print "Removing multicast groups"
        self.clearMulticast()
        if self.mc_sess_hdl:
            self.mc.mc_destroy_session(self.mc_sess_hdl)

    def importMulticastGroups(self, filename):
        self.mcast_groups = {}
        with open(filename, 'r') as f:
            for line in f:
                a,b = line.split(':')
                mgid = int(a)
                ports = map(int, b.split())
                self.mcast_groups[mgid] = ports

    def reloadCamusRules(self):
        self.clearMulticast()
        self.clearTables()

        entries_file, mcast_file = self.camus_compiler.compileRuntime(self.camus_rules)

        #entries_file, mcast_file = os.path.join(this_dir, "entries.json"), os.path.join(this_dir, "mcast.txt")

        self.importCamusEntries(entries_file)
        self.importMulticastGroups(mcast_file)

        self.popTables()
        self.setupMulticast()
        self.conn_mgr.complete_operations(self.shdl)

    def runTest(self):
        raise NotImplementedError


class HW(BaseTest):
    """ Just configure the tables on the actual switch """
    def runTest(self):
        if test_param_get('target') == 'asic-model': return # if not running on HW, return

        self.importCamusRules(self.camus_rules_file)
        self.camus_rules.append('ipv6.dstAddr = b001:0000:0000:0000:0000:0000:0000:0000/64 : fwd(37);')

        self.reloadCamusRules()

        print "Finished populating tables."
        raw_input("Hit ENTER to cleanup and exit...")
