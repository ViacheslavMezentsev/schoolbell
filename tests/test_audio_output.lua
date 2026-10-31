package.path="src/lua/?.lua;vendor/?.lua;"..package.path
-- Audio status supplement TC-01: metadata only, fixed endpoint, no fallback.
local M=require('schoolbell.audio_output')
local root='/sys/devices/platform/101c0000.ehci'
local usb=root..'/usb1/1-1/1-1.3'
local path=usb..'/1-1.3:1.0/sound/card0/dsp'
local values={[usb..'/idVendor']='0d8c',[usb..'/manufacturer']='C-Media Electronics Inc.  \n',[usb..'/product']='USB PnP Sound Device'}
local exists=true;local rdev=3587;local fail=false
local io={fs={stat=function(p)assert(p=='/dev/dsp');if not exists then return nil,2 end;return {type='chr',rdev=rdev,ino=10}end,realpath=function(p)
 if fail then error('unavailable')end
 if p=='/sys/dev/char/14:3' then return path end
 if p==root..'/driver' then return '/sys/bus/platform/drivers/ehci-platform'end
end},read=function(p)return values[p]end}
local s=M.read(io);assert(s.state=='ready' and s.controller=='EHCI' and s.name=='C-Media' and s.device=='/dev/dsp')
exists=false;assert(M.read(io).state=='missing');exists=true
fail=true;assert(M.read(io).state=='unknown');fail=false
rdev=3603;assert(M.read(io).state=='unknown');rdev=3587 -- never display metadata of another node
values[usb..'/manufacturer']='Generic';values[usb..'/product']='AB13X USB Audio';assert(M.read(io).name=='AB13X USB Audio')
values[usb..'/product']=string.rep('x',257);assert(M.read(io).name==nil)
local real=io.fs.realpath;local count=0
io.fs.realpath=function(p)if p=='/sys/dev/char/14:3' then count=count+1;if count==2 then return path..'changed'end end;return real(p)end
assert(M.read(io).state=='unknown')
io.fs.realpath=real;io.fs.stat=function()return nil,13 end;assert(M.read(io).state=='unknown')
print('PASS audio output: fixed endpoint, controller/name, absent/denied, unavailable sysfs, bounds and hotplug race')
