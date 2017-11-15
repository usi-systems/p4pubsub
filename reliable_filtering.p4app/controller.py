import subprocess
from appcontroller import AppController
from controller_rpc import RPCServer

class CustomAppController(AppController):

    def __init__(self, *args, **kwargs):
        AppController.__init__(self, *args, **kwargs)
        self.rpc_server = RPCServer(self)

    def start(self):
        self.rpc_server.start()
        AppController.start(self)

    def runCmd(self, cmd=None):
        commands = [cmd]
        self.sendCommands(commands)
        return True

    def stop(self):
        self.rpc_server.stop()
        AppController.stop(self)

