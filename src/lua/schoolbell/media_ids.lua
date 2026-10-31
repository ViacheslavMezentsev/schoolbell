-- Stable IDs, independent of files and the player. Legacy user1..user8 remain valid.
local M={bundled={'test','0','1','2','3','4'}}
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
