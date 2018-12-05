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

from intamp.p4_pd_rpc.ttypes import *
from mirror_pd_rpc.ttypes import *
from res_pd_rpc.ttypes import *
from pal_rpc.ttypes import *

from intamp_utils import *

this_dir = os.path.dirname(os.path.abspath(__file__))

INTAMP_UDP_PORT = 1234
LOOPBACK_PORT = 68
#LOOPBACK_PORT = 133 # set to your port to debug

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
        pd_base_tests.ThriftInterfaceDataPlane.__init__(self, ["intamp"])

        if test_param_get('target') == 'asic-model': # running on harlyn
            self.ingress_port = 0
            self.egress_port = 4
        else:
            self.ingress_port = 132 # ens2f1
            self.egress_port =  133 # ens2f0

        self.mgid = 5

        self.mirror_sessions = []
        self.loopback_ports = []


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
        #for entry in self.entries[table]:
        while len(self.entries[table]):
            entry = self.entries[table].pop()
            exec delete_func + "(self.shdl, self.dev, entry)"

    def tearDown(self):
        try:
            print("Clearing table entries")
            for table in self.entries.keys():
                self.clearTable(table)
            print("Removing mirror sessions")
            for h in self.mirror_sessions:
                self.mirror.mirror_session_delete(self.shdl, self.dev_tgt, h)
            print("Removing loopback ports")
            for port in self.loopback_ports:
                self.pal.pal_port_loopback_mode_set(dev_tgt.dev_id, port,
                                        pal_loopback_mod_t.BF_LPBK_NONE)
        except:
            print("Error while cleaning up. ")
            print("You might need to restart the driver")
        finally:
            self.conn_mgr.complete_operations(self.shdl)
            self.conn_mgr.client_cleanup(self.shdl)
            print("Closed Session %d" % self.shdl)
            pd_base_tests.ThriftInterfaceDataPlane.tearDown(self)

    def popForward(self):
        self.client.intamp_forward_set_default_action_set_mgid(self.shdl, self.dev_tgt,
                                intamp_set_mgid_action_spec_t(self.mgid))
        self.entries['forward'] = [self.client.intamp_forward_table_add_with_set_egress_port(
                self.shdl, self.dev_tgt,
                intamp_forward_match_spec_t(1),
                intamp_set_egress_port_action_spec_t(self.egr_port))]

    def popFromLoopback(self):
        self.entries['from_loopback'] = [self.client.intamp_from_loopback_table_add_with_modify_int(
                self.shdl, self.dev_tgt,
                intamp_from_loopback_match_spec_t(LOOPBACK_PORT))]


    def popTables(self):
        self.popForward()
        self.popFromLoopback()

    def setupMulticast(self):
        rid = 1
        lag_map = set_port_or_lag_bitmap(256, [])

        self.mc_grp_hdl = self.mc.mc_mgrp_create(self.mc_sess_hdl,
                                                    dev_id,
                                                    self.mgid)
        port_map = set_port_or_lag_bitmap(288, self.loopback_ports)
        self.mc_node_hdl = self.mc.mc_node_create(self.mc_sess_hdl, dev_id, rid, port_map,
					lag_map)
        self.mc.mc_associate_node(self.mc_sess_hdl, dev_id, self.mc_grp_hdl,
                                  self.mc_node_hdl, 0, 0)



    def runTest(self):
        self.popTables()
        self.setupMulticast()
        self.conn_mgr.complete_operations(self.shdl)


        pkt = int_packet(remaining_hop_cnt=1, switch_id=2, hop_latency=3, q_occupancy3=4)
        #print repr(pkt)
        send_packet(self, self.ingress_port, pkt)
        exp_pkt = pkt
        m = maskPkt(exp_pkt)
        verify_packet(self, m, self.ingress_port)

class SnakeTest(BaseTest):

    def setupMirroring(self):
        self.mirror_sessions.append(self.mirror.mirror_session_create(
                self.shdl, self.dev_tgt,
                mirror_session(mir_type=MirrorType_e.PD_MIRROR_TYPE_NORM,
                                  mir_dir=Direction_e.PD_DIR_INGRESS,
                                  sid=self.mir_ses,
                                  mcast_grp_a=self.mgid,
                                  mcast_grp_a_v=True,
                                  max_pkt_len=192)))

    def setupLoopback(self):
        for port in self.loopback_ports:
            self.pal.pal_port_loopback_mode_set(dev_tgt.dev_id, port,
                                pal_loopback_mod_t.BF_LPBK_MAC_NEAR)

    def popMirr(self):
        self.entries['snake_test_mirror'] = []
        self.entries['snake_test_mirror'].append(self.client.snake_test_mirror_table_add_with_snake_test_set_mir(
                    self.shdl, self.dev_tgt,
                    netgrep_snake_test_mirror_match_spec_t(hex_to_i16(self.server_port)),
                    netgrep_snake_test_set_mir_action_spec_t(hex_to_byte(self.mir_ses))))


    def runTest(self):
        #return # Comment this line to setup the snake test

        dfas = loadDFAs(os.path.join(this_dir, './snort256.3dfa.json'))

        self.mir_ses = 1
        self.mgid = 5

        server_fp_port = "1/2"
        self.server_port = front_panel_to_dev(self, dev_id, server_fp_port)
        print "The server sends packets on %s (%d)" % (server_fp_port, self.server_port)
        self.loopback_ports = []
        for pipe in [0, 1]:
            for port in range(0, 64):
                pipe_port = make_port(pipe, port)
                if pipe_port == self.server_port: continue # don't multicast to the server port
                self.loopback_ports.append(pipe_port)

        self.mc_sess_hdl = self.mc.mc_create_session()

        self.setupMulticast()
        self.setupMirroring()
        self.setupLoopback()
        self.popMirr()

        self.drop_nomatch = True
        repopTablesHack(dfas)
        self.popCopyConsumed()
        self.conn_mgr.complete_operations(self.shdl)

        print "Configured snake test"
        raw_input("Hit ENTER to cleanup and exit...")



class HW(BaseTest):
    """ Just configure the tables on the actual switch """
    def runTest(self):
        if test_param_get('target') == 'asic-model': return # if not running on HW, return
        self.popTables()
        self.setupMulticast()
        self.conn_mgr.complete_operations(self.shdl)

        print "Finished populating tables."
        raw_input("Hit ENTER to cleanup and exit.")

