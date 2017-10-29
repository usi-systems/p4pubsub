import struct
import socket
import errno
from linear_road import *

msg_type_struct = struct.Struct('!B')
position_report_struct = struct.Struct('!B H L B B B B B')
toll_notification_struct = struct.Struct('!B H L H B H')
accident_alert_struct = struct.Struct('!B H L H B')
accnt_bal_req_struct = struct.Struct('!B H L H')
accnt_bal_struct = struct.Struct('!B H L H H L')

def packPosReport(msg_type=LR_MSG_POS_REPORT, time=0, vid=0, spd=0,
                    xway=0, lane=0, dir=0, seg=0):
    assert 0 <= time and time <= 10799
    assert 0 <= spd and spd <= 100
    assert 0 <= lane and lane <= 4
    assert 0 <= dir and dir <= 1
    assert 0 <= seg and seg <= 99
    data = position_report_struct.pack(msg_type, time, vid, spd, xway, lane, dir, seg)
    return data

def unpackPosReport(data):
    msg_type, time, vid, spd, xway, lane, dir, seg = position_report_struct.unpack(data)
    assert msg_type == LR_MSG_POS_REPORT
    msg = PosReport(msg_type=msg_type, time=time, vid=vid, spd=spd,
                xway=xway, lane=lane, dir=dir, seg=seg)
    return msg

def packTollNotification(msg_type=LR_MSG_TOLL_NOTIFICATION, time=0, vid=0,
                            emit=0, spd=0, toll=0):
    data = toll_notification_struct.pack(msg_type, time, vid, emit, spd, toll)
    return data

def unpackTollNotification(data):
    msg_type, time, vid, emit, spd, toll = toll_notification_struct.unpack(data)
    assert msg_type == LR_MSG_TOLL_NOTIFICATION
    msg = TollNotification(msg_type=msg_type, time=time, vid=vid, emit=emit, spd=spd, toll=toll)
    return msg

def packAccidentAlert(msg_type=LR_MSG_ACCIDENT_ALERT, time=0, vid=0, emit=0, seg=0):
    data = accident_alert_struct.pack(msg_type, time, vid, emit, seg)
    return data

def unpackAccidentAlert(data):
    msg_type, time, vid, emit, seg = accident_alert_struct.unpack(data)
    assert msg_type == LR_MSG_ACCIDENT_ALERT
    msg = AccidentAlert(msg_type=msg_type, time=time, vid=vid, emit=emit, seg=seg)
    return msg

def packAccntBalReq(msg_type=LR_MSG_ACCNT_BAL_REQ, time=0, vid=0, qid=0):
    data = accnt_bal_req_struct.pack(msg_type, time, vid, qid)
    return data

def unpackAccntBalReq(data):
    msg_type, time, vid, qid = accnt_bal_req_struct.unpack(data)
    assert msg_type == LR_MSG_ACCNT_BAL_REQ
    msg = AccntBalReq(msg_type=msg_type, time=time, vid=vid, qid=qid)
    return msg

def packAccntBal(msg_type=LR_MSG_ACCNT_BAL, time=0, vid=0, emit=0, qid=0, bal=0):
    data = accnt_bal_struct.pack(msg_type, time, vid, emit, qid, bal)
    return data

def unpackAccntBal(data):
    msg_type, time, vid, emit, qid, bal = accnt_bal_struct.unpack(data)
    assert msg_type == LR_MSG_ACCNT_BAL
    msg = AccntBal(msg_type=msg_type, time=time, vid=vid, emit=emit, qid=qid, bal=bal)
    return msg


def unpackLRMsg(data):
    msg_type, = msg_type_struct.unpack(data[0])
    if msg_type == LR_MSG_POS_REPORT:
        return unpackPosReport(data)
    elif msg_type == LR_MSG_ACCIDENT_ALERT:
        return unpackAccidentAlert(data)
    elif msg_type == LR_MSG_TOLL_NOTIFICATION:
        return unpackTollNotification(data)
    elif msg_type == LR_MSG_ACCNT_BAL_REQ:
        return unpackAccntBalReq(data)
    elif msg_type == LR_MSG_ACCNT_BAL:
        return unpackAccntBal(data)
    else:
        raise Exception("Unrecognized msg type: %d" % msg_type)

def packLRMsg(msg):
    if isinstance(msg, PosReport):
        return packPosReport(**msg)
    elif isinstance(msg, AccidentAlert):
        return packAccidentAlert(**msg)
    elif isinstance(msg, TollNotification):
        return packTollNotification(**msg)
    elif isinstance(msg, AccntBalReq):
        return packAccntBalReq(**msg)
    elif isinstance(msg, AccntBal):
        return packAccntBal(**msg)
    else:
        raise Exception("Packing this msg type isn't supported yet")


def parseHostAndPort(host_and_port, default_port=1234):
    parts = host_and_port.split(':')
    assert len(parts) >= 1
    if len(parts) == 1:
        return (parts[0], default_port)
    else:
        return (parts[0], int(parts[1]))


class LRConsumer:

    def __init__(self, port, timeout=None):
        self.port = port
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind(('', self.port))
        self.sock.settimeout(timeout)
        self.recv_queue = []

    def recv(self):
        if len(self.recv_queue) > 0:
            data = self.recv_queue.pop()
        else:
            data, addr = self.sock.recvfrom(2048)
            if not data: return None

        msg = unpackLRMsg(data)
        return msg

    def hasNewMsg(self):
        try:
            self.sock.setblocking(0)
            data, addr = self.sock.recvfrom(2048)
            self.recv_queue.insert(0, data)
            return True
        except socket.error as e:
            err = e.args[0]
            if err == errno.EAGAIN or err == errno.EWOULDBLOCK:
                return False
            raise e
        finally:
            self.sock.setblocking(1)


    def recvMany(self, count, ignoretype=None):
        msgs = []
        while len(msgs) < count:
            msg = self.recv()
            if ignoretype is not None:
                if isinstance(msg, ignoretype):
                    continue
            msgs.append(msg)

        return msgs


    def close(self):
        self.sock.close()


class LRProducer:
    def __init__(self, dst_host, dst_port):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.dst_addr = (dst_host, dst_port)

    def send(self, msg):
        data = packLRMsg(msg)
        self.sock.sendto(data, self.dst_addr)

    def close(self):
        self.sock.close()