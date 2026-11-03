"""Real UDP handshake verifies heartbeat and PX4 parameter before startup."""
import importlib.machinery
import importlib.util
from pathlib import Path
import socket
import struct
import threading
import unittest
from unittest.mock import patch

PATH=Path(__file__).resolve().parents[1]/'onboard/autostart/src/fs150_onboard_autostart/scripts/read-fcu-identity'
loader=importlib.machinery.SourceFileLoader('identity',str(PATH))
spec=importlib.util.spec_from_loader(loader.name,loader);mod=importlib.util.module_from_spec(spec);loader.exec_module(mod)


def packet(msgid,payload,system=7):
    head=bytes([len(payload),0,system,1,msgid])
    return b'\xfe'+head+payload+struct.pack('<H',mod.crc(head+payload+bytes([mod.EXTRA[msgid]])))


class MavrosIdentityTest(unittest.TestCase):
    def handshake(self,heartbeat,param):
        server=socket.socket(socket.AF_INET,socket.SOCK_STREAM);server.bind(('127.0.0.1',0));server.listen();server.settimeout(2)
        def responder():
            peer=None
            try:
                peer,_=server.accept();peer.settimeout(2);buffer=b''
                while True:
                    data=peer.recv(1024)
                    if not data:break
                    rows,buffer=mod.split_frames(buffer+data)
                    for msgid,_,_,_ in rows:
                        if msgid==20:
                            payload=struct.pack('<iHH16sB',param,1,0,b'MAV_SYS_ID',6)
                            peer.sendall(packet(22,payload,heartbeat));peer.shutdown(socket.SHUT_WR)
                            while peer.recv(1024):pass
                            return
                        peer.sendall(packet(0,struct.pack('<IBBBBB',0,2,12,0,3,3),heartbeat))
            finally:
                if peer:peer.close()
                server.close()
        thread=threading.Thread(target=responder);thread.start()
        try:return mod.read_identity(server.getsockname(),timeout=2)
        finally:thread.join(3)

    def test_actual_id_is_read_from_parameter(self):
        self.assertEqual(self.handshake(7,7),7)

    def test_heartbeat_parameter_mismatch_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError,'disagree'):self.handshake(7,8)

    def test_wrong_expected_identity_prevents_startup(self):
        with patch.object(mod, 'read_identity', return_value=7), patch('sys.argv', ['read-fcu-identity', '--expected', '8']):
            with self.assertRaisesRegex(RuntimeError, 'expected from management IP=8'):mod.main()

    def test_partial_tcp_frame_is_retained(self):
        data=packet(0,struct.pack('<IBBBBB',0,2,12,0,3,3))
        rows,pending=mod.split_frames(data[:5]);self.assertEqual(rows,[])
        rows,pending=mod.split_frames(pending+data[5:]);self.assertEqual(len(rows),1);self.assertEqual(pending,b'')

    def test_bad_crc_is_ignored(self):
        data=packet(0,struct.pack('<IBBBBB',0,2,12,0,3,3));bad=data[:-1]+bytes([data[-1]^1])
        self.assertEqual(list(mod.messages(bad)),[])

    def test_concatenated_frames_are_parsed(self):
        data=packet(0,struct.pack('<IBBBBB',0,2,12,0,3,3))
        self.assertEqual(len(list(mod.messages(data+data))),2)


if __name__=='__main__':unittest.main()
