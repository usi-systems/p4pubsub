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

import pd_base_tests

from ptf import config
from ptf.testutils import *
from ptf.thriftutils import *
from ptf import mask

import os

from fwdsniff.p4_pd_rpc.ttypes import *
from mirror_pd_rpc.ttypes import *
from res_pd_rpc.ttypes import *
from pal_rpc.ttypes import *

this_dir = os.path.dirname(os.path.abspath(__file__))

dev_id = 0
dev_tgt = DevTarget_t(dev_id, hex_to_i16(0xFFFF))

def hex_to_i64(h):
    x = int(h)
    if (x > 0x7FFFFFFFFFFFFFFF): x-= 0x10000000000000000
    return x
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


CPU_PORT = 192

class BaseTest(pd_base_tests.ThriftInterfaceDataPlane):
    def __init__(self):
        pd_base_tests.ThriftInterfaceDataPlane.__init__(self, ["fwdsniff"])

        self.mirror_sessions = []
        self.loopback_ports = []

        self.mc_sess_hdl = None
        self.mc_node_hdls = []
        self.mc_grp_hdls = []

        self.fwd = {
                36: 37,
                37: 36,
                }

        self.sniff = True


    def setUp(self):
        pd_base_tests.ThriftInterfaceDataPlane.setUp(self)

        self.shdl = self.conn_mgr.client_init()
        self.dev      = 0
        self.dev_tgt  = DevTarget_t(self.dev, hex_to_i16(0xFFFF))

        self.entries = {}

        print("\nConnected to Device %d, Session %d" % (
            self.dev, self.shdl))

    def clearTable(self, table):
        delete_func = "self.client." + table + "_table_delete"
        while len(self.entries[table]):
            entry = self.entries[table].pop()
            exec delete_func + "(self.shdl, self.dev, entry)"

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

    def popTables(self):
        self.entries['fwd'] = []

        for ingr,egr in self.fwd.iteritems():
            if self.sniff:
                self.entries['fwd'].append(
                    self.client.fwd_table_add_with_set_mgid(self.shdl, self.dev_tgt,
                    fwdsniff_fwd_match_spec_t(hex_to_i16(ingr)),
                    fwdsniff_set_mgid_action_spec_t(hex_to_i16(egr))))
                print "ingr: %d => set_mgid(%d)" % (ingr, egr)
            else:
                self.entries['fwd'].append(
                    self.client.fwd_table_add_with_set_egr(self.shdl, self.dev_tgt,
                    fwdsniff_fwd_match_spec_t(hex_to_i16(ingr)),
                    fwdsniff_set_egr_action_spec_t(hex_to_i16(egr))))
                print "ingr: %d => set_egr(%d)" % (ingr, egr)

        # default egr port:
        self.client.fwd_set_default_action_set_egr(self.shdl, self.dev_tgt,
                fwdsniff_set_egr_action_spec_t(hex_to_i16(0)))

    def setupMulticast(self):
        self.mc_sess_hdl = self.mc.mc_create_session()

        mcast_groups = {}

        for port in self.fwd.values():
            mcast_groups[port] = [CPU_PORT, port]

        for mgid, ports in mcast_groups.items():
            rid = 1
            lag_map = set_port_or_lag_bitmap(256, [])

            print "MGID", mgid, "ports:", ports

            port_map = set_port_or_lag_bitmap(288, ports)

            node_hdl = self.mc.mc_node_create(self.mc_sess_hdl, dev_id, rid, port_map, lag_map)
            grp_hdl = self.mc.mc_mgrp_create(self.mc_sess_hdl, dev_id, mgid)

            self.mc.mc_associate_node(self.mc_sess_hdl, dev_id, grp_hdl, node_hdl, 0, 0)

            self.mc_node_hdls.append(node_hdl)
            self.mc_grp_hdls.append(grp_hdl)

        self.mc.mc_complete_operations(self.mc_sess_hdl)


    def teardownMulticast(self):
        if self.mc_sess_hdl is None: return
        print "Removing multicast groups"
        for grp_hdl, node_hdl in zip(self.mc_grp_hdls, self.mc_node_hdls):
            self.mc.mc_dissociate_node(self.mc_sess_hdl, dev_id, grp_hdl, node_hdl)
            self.mc.mc_mgrp_destroy(self.mc_sess_hdl, dev_id, grp_hdl)
            self.mc.mc_node_destroy(self.mc_sess_hdl, dev_id, node_hdl)
        self.mc.mc_destroy_session(self.mc_sess_hdl)

    def runTest(self):
        self.popTables()
        self.setupMulticast()
        self.conn_mgr.complete_operations(self.shdl)

        print "Populated tables."
        raw_input("Hit ENTER to cleanup and exit...")
