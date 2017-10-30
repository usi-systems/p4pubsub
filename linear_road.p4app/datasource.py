import sys
from linear_road import *

class LRDataSource:

    def __init__(self, filename=None, fd=None):
        self.vid_map = {}
        self.last_vid = 0
        if fd:
            self.filename = None
            self.fd = fd
        else:
            self.filename = filename

    def open(self):
        if self.filename:
            self.fd = open(self.filename, 'r')

    def close(self):
        print self.vid_map
        self.fd.close()

    def next(self):
        l = next(self.fd)
        m = map(int, l.strip().split(','))
        if m[0] == LR_MSG_POS_REPORT:
            if m[2] not in self.vid_map:
                self.last_vid += 1
                self.vid_map[m[2]] = self.last_vid
            return PosReport(time=m[1],
                             vid=self.vid_map[m[2]],
                             spd=m[3],
                             xway=m[4],
                             lane=m[5],
                             dir=m[6],
                             seg=m[7])
        elif m[0] == LR_MSG_ACCNT_BAL_REQ:
            return AccntBalReq(time=m[1],
                             vid=self.vid_map[m[2]],
                             qid=m[9])
        # we don't handle daily expenditure or travel time estimate
        elif m[0] in [3, 4]:
            return next(self)
        else:
            raise Exception("Unsupported message type: %d" % m[0])

    def __iter__(self): return self

    def __enter__(self):
        self.open()
        return self

    def __exit__(self, t, v, tb): self.close()



