"""One bounded transfer with a durable receipt. Called only by the elevated helper."""
import argparse, hashlib, json, os, uuid, time, logging
from pathlib import Path
from firmware import PROFILES, RECOVERY_BYTES
from tftp_server import serve

def write(path, state):
    temp=path.with_suffix('.tmp')
    with temp.open('w',encoding='utf-8') as f:
        json.dump(state,f,ensure_ascii=False);f.flush();os.fsync(f.fileno())
    # Windows readers can briefly hold the destination without delete sharing.
    # Retain the write-ahead barrier, but tolerate this bounded local contention.
    for attempt in range(100):
        try:
            os.replace(temp,path)
            break
        except PermissionError:
            if attempt == 99: raise
            time.sleep(0.01)

def run(profile, root, operation, transport=serve):
    operation=str(uuid.UUID(operation));root=Path(root)
    path=root/'flash-session.json'
    state=json.loads(path.read_text(encoding='utf-8-sig'))
    if state.get('operation')!=operation or state.get('profile')!=profile or state.get('phase')!='preparing':
        raise ValueError('Mismatched firmware session')
    data=(root/(profile+'.bin')).read_bytes()
    if len(data)!=RECOVERY_BYTES or hashlib.sha256(data).hexdigest()!=PROFILES[profile][1]:
        raise ValueError('Unpinned firmware bytes')
    def event(phase,count):
        state.update(phase=phase,acknowledged=count)
        if phase=='transferring':state['possible_write']=True
        if phase=='transferred':state['transfer_complete']=True
        write(path,state)
    try:
        if transport is serve:
            cancel=Path(__file__).resolve().parent/('flash-stop-'+operation+'.request')
            transport(data,event,cancelled=cancel.exists)
        else:transport(data,event)
    except Exception:
        logging.exception("Firmware transfer failed")
        state['phase']='unknown' if state.get('possible_write') else 'not-started'
        write(path,state)
        raise

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--profile',choices=PROFILES,required=True);p.add_argument('--root',type=Path,required=True);p.add_argument('--operation',required=True)
    a=p.parse_args()
    logging.basicConfig(filename=a.root/('transfer-'+str(uuid.UUID(a.operation))+'.log'),level=logging.INFO,format='%(asctime)s %(levelname)s %(message)s')
    run(a.profile,a.root,a.operation)
