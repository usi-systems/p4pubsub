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

from caramp.p4_pd_rpc.ttypes import *
from mirror_pd_rpc.ttypes import *
from res_pd_rpc.ttypes import *
from pal_rpc.ttypes import *

this_dir = os.path.dirname(os.path.abspath(__file__))

CARAMP_UDP_PORT = 1234
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
        pd_base_tests.ThriftInterfaceDataPlane.__init__(self, ["caramp"])

        if test_param_get('target') == 'asic-model': # running on harlyn
            self.ingress_port = 0
            self.egress_ports = [4]
        else:
            self.ingress_port = 46
            self.egress_ports =  [168, 169, 170, 171]

        self.mgid = 5
        self.loopback_port = 1

        self.mirror_sessions = []
        self.loopback_ports = []

        self.mc_sess_hdl = None
        self.mc_node_hdl = None
        self.mc_grp_hdl = None


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
            self.teardownMulticast()
        except:
            print("Error while cleaning up. ")
            print("You might need to restart the driver")
        finally:
            self.conn_mgr.complete_operations(self.shdl)
            self.conn_mgr.client_cleanup(self.shdl)
            print("Closed Session %d" % self.shdl)
            pd_base_tests.ThriftInterfaceDataPlane.tearDown(self)

    def popForward(self):
        self.client.forward_set_default_action_set_mgid(self.shdl, self.dev_tgt,
                                caramp_set_mgid_action_spec_t(self.mgid))
        #self.entries['forward'] = [self.client.forward_table_add_with_set_egress_port(
        #        self.shdl, self.dev_tgt,
        #        caramp_forward_match_spec_t(1),
        #        caramp_set_egress_port_action_spec_t(self.egress_port))]
        self.entries['forward'] = [self.client.forward_table_add_with__drop(
                self.shdl, self.dev_tgt,
                caramp_forward_match_spec_t(0))]

    def popUpdateCar(self):
        self.client.update_car_fields_set_default_action_decr_car_fields(self.shdl, self.dev_tgt,
                caramp_decr_car_fields_action_spec_t(hex_to_i16(1)))
        #self.entries['update_car_fields'] = [self.client.update_car_fields_table_add_with_nop(
        #        self.shdl, self.dev_tgt,
        #        caramp_update_car_fields_match_spec_t(
        #            self.ingress_port, self.ingress_port, hex_to_byte(0), hex_to_byte(220)), 1)]
        #self.entries['update_car_fields'] = [self.client.update_car_fields_table_add_with_set_car_fields(
        #        self.shdl, self.dev_tgt,
        #        caramp_update_car_fields_match_spec_t(0, 0, hex_to_byte(95), hex_to_byte(96)), 1,
        #        caramp_set_car_fields_action_spec_t(hex_to_i32(22), hex_to_i32(8000), hex_to_byte(1)))]


    def popTables(self):
        self.popForward()
        self.popUpdateCar()

    def setupMulticast(self):
        rid = 1
        lag_map = set_port_or_lag_bitmap(256, [])

        self.mc_sess_hdl = self.mc.mc_create_session()

        ports = [self.loopback_port] + self.egress_ports

        port_map = set_port_or_lag_bitmap(288, ports)
        print "MGID", self.mgid, "ports:", ports
        self.mc_node_hdl = self.mc.mc_node_create(self.mc_sess_hdl, dev_id, rid, port_map,
					lag_map)

        self.mc_grp_hdl = self.mc.mc_mgrp_create(self.mc_sess_hdl,
                                                    dev_id,
                                                    self.mgid)
        self.mc.mc_associate_node(self.mc_sess_hdl, dev_id, self.mc_grp_hdl,
                                  self.mc_node_hdl, 0, 0)

        self.mc.mc_complete_operations(self.mc_sess_hdl)

    def teardownMulticast(self):
        if self.mc_sess_hdl is None: return
        print "Removing multicast groups"
        self.mc.mc_dissociate_node(self.mc_sess_hdl, dev_id, self.mc_grp_hdl, self.mc_node_hdl)
        self.mc.mc_mgrp_destroy(self.mc_sess_hdl, dev_id, self.mc_grp_hdl)
        self.mc.mc_node_destroy(self.mc_sess_hdl, dev_id, self.mc_node_hdl)
        self.mc.mc_destroy_session(self.mc_sess_hdl)

    def runTest(self):
        self.popTables()
        self.setupMulticast()
        self.conn_mgr.complete_operations(self.shdl)



class HW(BaseTest):
    """ Just configure the tables on the actual switch """
    def runTest(self):
        if test_param_get('target') == 'asic-model': return # if not running on HW, return

        self.loopback_port = LOOPBACK_PORT

        self.popTables()
        self.setupMulticast()
        self.conn_mgr.complete_operations(self.shdl)

        print "Finished populating tables."
        raw_input("Hit ENTER to cleanup and exit...")
