-- Stable IDs, independent of files and the player. Legacy user1..user8 remain valid.
local M={bundled={'test','0','1','2','3','4'}}
-- Immutable package metadata shared by browser file delivery and the device player.
M.sizes={test=13104,['0']=41273,['1']=63321,['2']=69904,['3']=68023,['4']=82368}
M.test_etag='"1ae57af4d27698b0cd3795de7287c0dd1b5e2b336e8d9e8dcc9b853cbd8b4e0d"'
local paths={}
for _,id in ipairs(M.bundled)do paths[id]='/usr/share/schoolbell-sound-test/'..id..'.mp3' end
function M.packaged(id)return paths[id],M.sizes[id]end
function M.user(id)return type(id)=='string' and #id<=64 and (id:match('^user[1-9]%d*$')~=nil or id:match('^user_[0-9a-f]+$')~=nil)end
function M.valid(id)if M.user(id)then return true end;for _,v in ipairs(M.bundled)do if v==id then return true end end;return false end
function M.references(d)
 local out,seen={},{}
 local function add(id)assert(M.valid(id),'media_reference');if not seen[id]then seen[id]=true;out[#out+1]=id end end
 for _,id in ipairs(M.bundled)do add(id)end
 add(d.pre_media);add(d.manual_media or 'test')
 for _,s in ipairs(d.schedules)do for _,row in ipairs(s.rows)do add(row.media)end end
 return out
end
return M
