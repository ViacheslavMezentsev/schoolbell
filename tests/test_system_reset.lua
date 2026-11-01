package.path='src/lua/?.lua;vendor/?.lua;'..package.path
local Reset=require('schoolbell.system_reset');local C=require('schoolbell.media_codec');local S=require('schoolbell.schedule_store');local A=require('schoolbell.automatic_store')
local function envelope(v)return C.encode({data=v,checksum=C.sha(C.encode(v))})end
local function fixture()
 local draft=S.empty();draft.pre_media='user1';draft.schedules={{id='s',name='School',rows={{id='r',time='08:00',media='user1',enabled=true,pre=false}}}}
 local d={['current.json']=envelope(draft),['previous.json']='old', ['automatic.json']=envelope({enabled=true,generation=3,watermark=100,plan=draft,revision=C.sha(C.encode(draft)),boot='boot',zone='UTC'}),['sound-control.json']=C.encode({muted=true,volume_db=-12,generation=7}),['clock-policy.json']='{"enforced":false}', ['journal-current.jsonl']='journal bytes', ['clock-reference.json']='clock reference', ['import-receipts.json']='old receipt'}
 local fs={read=function(n,max)local v=d[n];assert(not v or #v<=max);return v end,stat=function(n)return d[n]and {type='reg',size=#d[n]}end,write=function(n,v)assert(not d[n]);d[n]=v end,rename=function(a,b)assert(d[a]);d[b]=d[a];d[a]=nil end,unlink=function(n)assert(d[n]);d[n]=nil end,sync=function()end,space=function()return 2000000,4000000 end}
 return fs,d
end
local function verify(fs,d)
 assert(S.load(fs).data.mode=='fixed' and #S.load(fs).data.schedules==0)
 local auto=A.decode(d['automatic.json']);assert(not auto.enabled and not auto.plan and auto.generation==4)
 local v=C.decode(d['sound-control.json']);assert(v.volume_db==0 and not v.muted and v.generation==8)
 assert(C.decode(d['clock-policy.json']).enforced and not d['restore.pending'])
 assert(d['journal-current.jsonl']=='journal bytes' and d['clock-reference.json']=='clock reference')
 assert(not d['previous.json']and not d['import-receipts.json'])
end
local fs,d=fixture();assert(Reset.apply(fs,string.rep('a',32)).ok);verify(fs,d)
for _,stage in ipairs({'pending','disabled','draft','controls','policy','cleanup','verified'})do
 fs,d=fixture();assert(not pcall(Reset.apply,fs,string.rep('a',32),function(at)if at==stage then error('power interruption')end end))
 assert(d['restore.pending']);assert(Reset.apply(fs,string.rep('b',32)).ok);verify(fs,d)
end
fs,d=fixture();local original=d['current.json'];fs.space=function()return 0,4000000 end
assert(not pcall(Reset.apply,fs,string.rep('a',32)));assert(not d['restore.pending']and d['current.json']==original)
fs,d=fixture();d['restore.pending']='{"data":{"kind":"other"},"checksum":"x"}';assert(not pcall(Reset.apply,fs,string.rep('a',32)))
print('PASS reset: defaults, auto off, generations, journal/time reference preservation, all interrupted phases resume, no space and foreign restore refusal')
