import subprocess
from appcontroller import AppController
from controller_rpc import RPCServer
from linear_road import *

def stoppedIdx(xway, seg, dir, lane):
    """ Index into register of counters of stopped vehicles for each location """
    return (xway * (LR_NUM_SEG * LR_NUM_DIRS * LR_NUM_LANES)) + (seg * LR_NUM_DIRS * LR_NUM_LANES) + (dir * LR_NUM_LANES) + lane

class CustomAppController(AppController):

    def __init__(self, *args, **kwargs):
        AppController.__init__(self, *args, **kwargs)
        self.rpc_server = RPCServer(self)

    def start(self):
        self.rpc_server.start()
        AppController.start(self)

    def getStoppedCnt(self, xway=None, seg=None, dir=None, lane=None):
        idx = stoppedIdx(xway, seg, dir, lane)
        cnt = self.readRegister('stopped_cnt_reg', idx)
        return int(cnt)

    def getVidState(self, vid=None):
        state = LRMsg(dir=0)
        for k in ['spd', 'valid', 'seg', 'xway', 'lane']:
            v = self.readRegister('v_%s_reg' % k, vid)
            state[k] = int(v)
        return state

    def stop(self):
        v_state = self.getVidState(vid=1)
        stp_cnt = self.getStoppedCnt(**v_state.loc())
        print v_state
        print "stp_cnt:", stp_cnt
        self.rpc_server.stop()
        AppController.stop(self)

