local C=require('schoolbell.media_codec');local M={}
function M.save(root,enforced)
 local fs;local ok=pcall(function()
  fs=require('schoolbell.media_fs').new(root)
  if not fs.stat('clock-policy.pending')then fs.write('clock-policy.pending','pending')end
  fs.sync('clock-policy.pending');fs.sync('')
  if fs.stat('clock-policy.next')then fs.unlink('clock-policy.next')end
  local raw=C.encode({enforced=enforced})
  fs.write('clock-policy.next',raw);fs.sync('clock-policy.next')
  fs.rename('clock-policy.next','clock-policy.json');fs.sync('')
  assert(fs.read('clock-policy.json',256)==raw)
  fs.unlink('clock-policy.pending');fs.sync('')
 end)
 if not ok and fs then pcall(function()if not fs.stat('clock-policy.pending')then fs.write('clock-policy.pending','pending')end;fs.sync('clock-policy.pending');fs.sync('')end)end
 if fs then local closed=pcall(fs.close);ok=ok and closed end
 return ok
end
return M
