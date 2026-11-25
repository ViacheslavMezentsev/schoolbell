"""Prepare pinned Qt resources locally. No network, hardware or generic OEM conversion."""
import argparse, hashlib, io, sys, zipfile
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent.parent))
from firmware import OPENWRT_SHA, RECOVERY_BYTES, prepare_oem
OEM_ZIP_SHA='c01e8ad8c882ee2cc5dbb2899111f111c37aa356d366f0b6098f6c5f139bacea'
def prepare(openwrt, oem, destination):
    data=Path(openwrt).read_bytes()
    if len(data)!=RECOVERY_BYTES or hashlib.sha256(data).hexdigest()!=OPENWRT_SHA:
        raise ValueError('Unpinned OpenWrt image')
    archive=Path(oem).read_bytes()
    if hashlib.sha256(archive).hexdigest()!=OEM_ZIP_SHA:raise ValueError('Unpinned OEM archive')
    with zipfile.ZipFile(io.BytesIO(archive)) as z:
        bins=[n for n in z.namelist() if n.lower().endswith('.bin')]
        if len(bins)!=1:raise ValueError('Ambiguous OEM image')
        stock=prepare_oem(z.read(bins[0]))
    destination=Path(destination);destination.mkdir(parents=True,exist_ok=False)
    (destination/'openwrt.bin').write_bytes(data)
    (destination/'factory.bin').write_bytes(stock)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--openwrt',required=True);p.add_argument('--oem',required=True);p.add_argument('--out',required=True)
    a=p.parse_args();prepare(a.openwrt,a.oem,a.out)
