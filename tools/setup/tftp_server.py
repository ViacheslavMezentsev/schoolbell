import argparse, hashlib, logging, socket, struct, time
from pathlib import Path

EXPECTED = 'e621da95d07d25102b1016a28400122f5c92bce9830d5cc061323e306b6204fa'
ROOT = Path(__file__).resolve().parent

def valid_rrq(data):
    fields = data[2:].split(b'\0')
    return (data[:2] == b'\0\1' and data.endswith(b'\0') and len(data) <= 512
            and len(fields) >= 3 and (len(fields)-3) % 2 == 0
            and fields[0] == b'tp_recovery.bin' and fields[1].lower() == b'octet')

def transfer(sock, peer, payload, timeout=1.0, retries=6):
    acknowledged = 0
    for offset in range(0, len(payload)+1, 512):
        chunk = payload[offset:offset+512]
        block = offset//512+1
        packet = struct.pack('!HH', 3, block) + chunk
        for attempt in range(retries):
            sock.sendto(packet, peer)
            if block == 1 or attempt or block % 1024 == 0 or len(chunk)<512:
                logging.info('DATA block=%s bytes=%s attempt=%s local=%s peer=%s', block,len(chunk),attempt+1,sock.getsockname(),peer)
            deadline = time.monotonic()+timeout
            accepted = False
            while time.monotonic()<deadline:
                sock.settimeout(max(0.001,deadline-time.monotonic()))
                try: reply, source = sock.recvfrom(2048)
                except socket.timeout: break
                if source != peer:
                    logging.warning('Ignored other peer %s',source)
                    continue
                if len(reply)>=4 and reply[:2]==b'\0\5':
                    raise RuntimeError('Client ERROR: '+repr(reply))
                if reply == struct.pack('!HH',4,block):
                    accepted=True
                    break
                logging.warning('Unexpected reply block=%s hex=%s',block,reply.hex())
            if accepted: break
            logging.warning('ACK TIMEOUT block=%s attempt=%s',block,attempt+1)
        else: raise TimeoutError('No ACK for block '+str(block))
        acknowledged += len(chunk)
        if block==1 or block%1024==0 or len(chunk)<512:
            logging.info('ACK block=%s acknowledged_bytes=%s',block,acknowledged)
            print(f'ACK: {acknowledged}/{len(payload)} bytes ({100*acknowledged/max(1,len(payload)):.1f}%)', flush=True)
        if len(chunk)<512: break
    return acknowledged

def self_test():
    import threading
    assert valid_rrq(b'\0\1tp_recovery.bin\0octet\0timeout\x001\0')
    assert not valid_rrq(b'\0\2tp_recovery.bin\0octet\0')
    assert not valid_rrq(b'\0\1../tp_recovery.bin\0octet\0')
    for size in (0,1,512,1024,1300):
        payload=bytes(i%251 for i in range(size)); result=[]; received=bytearray()
        with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as server, socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as client:
            server.bind(('127.0.0.1',0)); client.bind(('127.0.0.1',0)); client.settimeout(2)
            def worker():
                try: result.append(transfer(server,client.getsockname(),payload,.1,3))
                except Exception as exc: result.append(exc)
            thread=threading.Thread(target=worker); thread.start()
            first=True; previous=0
            while True:
                packet,peer=client.recvfrom(2048); opcode,block=struct.unpack('!HH',packet[:4])
                assert opcode==3
                if first:
                    first=False
                    continue  # lose first ACK / force retransmission
                if block!=previous: received.extend(packet[4:]); previous=block
                client.sendto(struct.pack('!HH',4,block),peer)
                if len(packet)<516: break
            thread.join(2)
            assert result==[size],result
            assert bytes(received)==payload
    print('PASS: RRQ restrictions, byte identity, terminal empty block, retransmission')

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--self-test',action='store_true'); args=parser.parse_args()
    if args.self_test: self_test(); return
    logging.basicConfig(filename=ROOT/'tftp-python-openwrt-19.07.9.log',level=logging.INFO,format='%(asctime)s %(levelname)s %(message)s')
    payload=(ROOT/'firmware'/'tp_recovery.bin').read_bytes()
    digest=hashlib.sha256(payload).hexdigest()
    if digest!=EXPECTED: raise RuntimeError('Firmware hash mismatch')
    logging.info('START OpenWrt 19.07.9 size=%s sha256=%s no OACK, read-only, client=192.168.0.2',len(payload),digest)
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as listener:
        listener.bind(('192.168.0.225',69)); listener.settimeout(1)
        print('READY 192.168.0.225:69; OpenWrt 19.07.9 recovery verified. Waiting for router.',flush=True)
        expires=time.monotonic()+600
        while time.monotonic()<expires:
            try: request,peer=listener.recvfrom(2048)
            except socket.timeout: continue
            logging.info('RRQ peer=%s hex=%s',peer,request.hex())
            if peer[0]!='192.168.0.2' or not valid_rrq(request):
                logging.warning('REJECT request'); continue
            try:
                with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sender:
                    sender.bind(('192.168.0.225',1069))
                    count=transfer(sender,peer,payload)
                logging.info('TRANSFER COMPLETE acknowledged=%s; flash write NOT verified',count)
                print('TRANSFER COMPLETE. Keep router powered. Flash write not yet verified.',flush=True)
                return
            except (OSError,RuntimeError) as exc:
                logging.exception('TRANSFER FAILED %s',exc)
                print('TRANSFER FAILED; see tftp-python-openwrt-19.07.9.log',flush=True)
                raise SystemExit(1)  # no queued RRQ replay
        raise TimeoutError('No recovery request within 10 minutes')

if __name__=='__main__': main()
