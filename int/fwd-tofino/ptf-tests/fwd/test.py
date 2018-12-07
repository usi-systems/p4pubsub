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

from fwd.p4_pd_rpc.ttypes import *
from mirror_pd_rpc.ttypes import *
from res_pd_rpc.ttypes import *
from pal_rpc.ttypes import *

this_dir = os.path.dirname(os.path.abspath(__file__))


class BaseTest(pd_base_tests.ThriftInterfaceDataPlane):
    def __init__(self):
        pd_base_tests.ThriftInterfaceDataPlane.__init__(self, ["fwd"])

        self.mirror_sessions = []
        self.loopback_ports = []

        self.fwd = {
                46: 168,
                168: 46,
                }


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
            self.entries['fwd'].append(
                    self.client.fwd_table_add_with_set_egr(self.shdl, self.dev_tgt,
                    fwd_fwd_match_spec_t(hex_to_i16(ingr)),
                    fwd_set_egr_action_spec_t(hex_to_i16(egr))))
            print "ingr: %d => set_egr(%d)" % (ingr, egr)

        # default egr port:
        self.client.fwd_set_default_action_set_egr(self.shdl, self.dev_tgt,
                fwd_set_egr_action_spec_t(hex_to_i16(169)))

    def runTest(self):
        self.popTables()
        self.conn_mgr.complete_operations(self.shdl)

        print "Populated tables."
        raw_input("Hit ENTER to cleanup and exit...")
