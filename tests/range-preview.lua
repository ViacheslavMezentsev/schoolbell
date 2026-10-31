local S=require('schoolbell.schedule_store');local C=require('schoolbell.media_codec')
local f=assert(io.open(arg[1],'rb'));local raw=f:read('*a');f:close()
for i=2,#arg do print(C.encode(S.preview(raw,arg[i])))end
