"""Pure firmware preflight. Consumes a snapshot; never inspects or changes a host."""
import argparse
import copy
import hashlib
import ipaddress
import json
from pathlib import Path
import uuid
from firmware import PROFILES, RECOVERY_BYTES

TARGETS=tuple(map(ipaddress.IPv4Address,('192.168.0.2','192.168.0.225','192.168.1.1','192.168.1.2')))

def plan(snapshot, selected_guid, profile, confirmed_model):
    if profile not in PROFILES: raise ValueError('Unknown firmware profile')
    if confirmed_model!='MR3020 EU V3.30': raise ValueError('Confirm model and revision from the device label')
    guid=str(uuid.UUID(selected_guid))
    if snapshot.get('schema')!=1: raise ValueError('Unsupported snapshot schema')
    adapters=snapshot['adapters'];routes=snapshot['routes'];ports=snapshot['udp_ports']
    if not all(isinstance(v,list) for v in (adapters,routes,ports)): raise ValueError('Invalid snapshot lists')
    identities=[str(uuid.UUID(a['guid'])) for a in adapters]
    indexes=[a['index'] for a in adapters]
    if len(set(identities))!=len(identities) or len(set(indexes))!=len(indexes): raise ValueError('Ambiguous adapter identity')
    if any(type(i)!=int or i<1 for i in indexes): raise ValueError('Invalid adapter index')
    if guid not in identities: raise ValueError('Selected adapter disappeared')
    adapter=adapters[identities.index(guid)]
    blockers=[];warnings=[]
    def block(code):
        if code not in blockers:blockers.append(code)
    for flag in ('physical','usb','dhcp','link_up'):
        if type(adapter.get(flag))!=bool: raise ValueError('Missing adapter flag: '+flag)
        if not adapter[flag]:block('adapter-'+flag.replace('_','-'))
    if adapter.get('media')!='ethernet':block('adapter-media')
    if type(snapshot.get('pending_restore'))!=bool: raise ValueError('Missing restoration state')
    if snapshot['pending_restore']:block('pending-restore')
    for a in adapters:
        for address in a['addresses']:
            ip=ipaddress.IPv4Address(address['ip'])
            if address['origin'] not in ('dhcp','manual','well-known'):raise ValueError('Unknown address origin')
            if a is adapter and address['origin']=='manual':block('manual-address')
            if ip in TARGETS:block('reserved-address-in-use')
    for route in routes:
        net=ipaddress.IPv4Network(route['prefix'],strict=False)
        hop=ipaddress.IPv4Address(route['next_hop'])
        if type(route['index'])!=int or route['index']<1:raise ValueError('Invalid route index')
        if route['index']==adapter['index'] or net.prefixlen==0:continue
        if any(ip in net for ip in TARGETS):
            if net.prefixlen>24 or hop==ipaddress.IPv4Address('0.0.0.0'):block('conflicting-route')
            elif 'gateway-route-recheck' not in warnings:warnings.append('gateway-route-recheck')
    if any(type(p)!=int or not 0<p<65536 for p in ports):raise ValueError('Invalid UDP port')
    if set(ports)&{69,1069}:block('tftp-port-busy')
    filename,digest,label=PROFILES[profile]
    snapshot_hash=hashlib.sha256(json.dumps(snapshot,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    return dict(schema=1,mode='dry-run',ready=False,eligible=not blockers,
        snapshot_sha256=snapshot_hash,adapter=copy.deepcopy(adapter),blockers=blockers,warnings=warnings,
        image=dict(profile=profile,file=filename,sha256=digest,size=RECOVERY_BYTES,label=label,verified=False),
        steps=['verify-image','save-network-state','revalidate-adapter-and-routes','add-recovery-address',
               'verify-direct-route','add-scoped-firewall','start-tftp','wait-for-boot','verify-os','restore-network'],
        temporary=dict(address='192.168.0.225/24',client='192.168.0.2',udp_ports=[69,1069]),
        restore=dict(adapter_guid=guid,dhcp=True,remove_only_owned_addresses=True,remove_only_owned_firewall=True),
        note='Plan only. No UAC, host changes, TFTP, SSH or device access. Not READY.')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--snapshot',type=Path,required=True)
    parser.add_argument('--adapter-guid',required=True)
    parser.add_argument('--profile',choices=PROFILES,required=True)
    parser.add_argument('--model',required=True)
    args=parser.parse_args()
    if args.snapshot.stat().st_size>1024*1024:raise ValueError('Snapshot too large')
    result=plan(json.loads(args.snapshot.read_text(encoding='utf-8-sig')),args.adapter_guid,args.profile,args.model)
    print(json.dumps(result,ensure_ascii=False,indent=2))
    return 0 if result['eligible'] else 2

if __name__=='__main__':raise SystemExit(main())
