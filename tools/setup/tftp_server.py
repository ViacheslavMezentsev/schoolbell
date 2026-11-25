import argparse, hashlib, logging, socket, struct, time
from pathlib import Path

from firmware import load_payload, PROFILES
ROOT = Path(__file__).resolve().parent

def valid_rrq(data):
    fields = data[2:].split(b'\0')
    return (data[:2] == b'\0\1' and data.endswith(b'\0') and len(data) <= 512
            and len(fields) >= 3 and (len(fields)-3) % 2 == 0
            and fields[0] == b'tp_recovery.bin' and fields[1].lower() == b'octet')

def transfer(sock, peer, payload, timeout=1.0, retries=6, progress=None, cancelled=lambda:False):
    acknowledged = 0
    for offset in range(0, len(payload)+1, 512):
        chunk = payload[offset:offset+512]
        block = offset//512+1
        packet = struct.pack('!HH', 3, block) + chunk
        for attempt in range(retries):
            if cancelled():raise InterruptedError('Transfer stopped by user')
            sock.sendto(packet, peer)
            if block == 1 or attempt or block % 1024 == 0 or len(chunk)<512:
                logging.info('DATA block=%s bytes=%s attempt=%s local=%s peer=%s', block,len(chunk),attempt+1,sock.getsockname(),peer)
            deadline = time.monotonic()+timeout
            accepted = False
            while time.monotonic()<deadline:
                if cancelled():raise InterruptedError('Transfer stopped by user')
                sock.settimeout(min(0.2,max(0.001,deadline-time.monotonic())))
                try: reply, source = sock.recvfrom(2048)
                except socket.timeout: continue
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
        if progress and (block==1 or block%128==0 or len(chunk)<512): progress(acknowledged)
        if block==1 or block%1024==0 or len(chunk)<512:
            logging.info('ACK block=%s acknowledged_bytes=%s',block,acknowledged)
            print(f'ACK: {acknowledged}/{len(payload)} bytes ({100*acknowledged/max(1,len(payload)):.1f}%)', flush=True)
        if len(chunk)<512: break
    return acknowledged


def serve(payload, event=lambda phase,count: None, wait_seconds=600,
          bind='192.168.0.225', client='192.168.0.2', port=69, data_port=1069, cancelled=lambda:False):
    """One recovery request; callbacks are durable before first DATA. No RRQ replay.

    Alternate endpoints exist only for loopback tests; product callers use fixed defaults.
    """
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as listener, socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sender:
        listener.bind((bind,port));sender.bind((bind,data_port));listener.settimeout(0.5)
        event('ready',0)
        expires=time.monotonic()+wait_seconds
        while time.monotonic()<expires:
            if cancelled():raise InterruptedError('Waiting stopped by user')
            try: request,peer=listener.recvfrom(2048)
            except socket.timeout:continue
            if peer[0]!=client or not valid_rrq(request):continue
            if cancelled():raise InterruptedError('Waiting stopped by user')
            event('transferring',0)  # Write-ahead marker: failure here sends no bytes.
            count=transfer(sender,peer,payload,progress=lambda n:event('transferring',n),cancelled=cancelled)
            event('transferred',count)
            return count
        event('not-started',0)
        raise TimeoutError('No recovery request within time limit')

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
    parser=argparse.ArgumentParser()
    parser.add_argument('--self-test',action='store_true')
    parser.add_argument('--profile',choices=PROFILES,default='openwrt')
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    if args.self_test: self_test(); return
    payload, label = load_payload(ROOT, args.profile)
    digest=hashlib.sha256(payload).hexdigest()
    if args.check:
        print(f'CHECK OK: {label}; {len(payload)} bytes; SHA256 {digest}')
        return
    logfile=ROOT/('tftp-'+args.profile+'.log')
    logging.basicConfig(filename=logfile,level=logging.INFO,format='%(asctime)s %(levelname)s %(message)s')
    logging.info('START %s size=%s sha256=%s no OACK, read-only, client=192.168.0.2',label,len(payload),digest)
    def report(phase,count):
        if phase=='ready':print(f'READY 192.168.0.225:69; {label}; SHA256 {digest}. Waiting for router.',flush=True)
        if phase=='transferred':print('TRANSFER COMPLETE. Keep router powered. Flash write not yet verified.',flush=True)
    serve(payload,report)

if __name__=='__main__': main()
