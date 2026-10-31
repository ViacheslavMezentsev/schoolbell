import json, os, pathlib, shutil, subprocess, sys, tempfile
repo=pathlib.Path(sys.argv[1])
driver=repo/"tests/schedule_store_driver.lua"
with tempfile.TemporaryDirectory(prefix="schoolbell-editor-test-") as tmp:
    top=pathlib.Path(tmp); a=top/"a.json";b=top/"b.json"
    data={"schedules":[{"id":"main","name":"Учебный день","color":16,"rows":[{"id":"r1","time":"08:00","media":"test","enabled":True,"pre":True}]}],"pre_minutes":2,"pre_media":"test","plans":[{"year":2028,"schedule_ids":["main"],"days":"A"*366}]}
    a.write_text(json.dumps(data,ensure_ascii=False));data["schedules"][0]["rows"][0]["time"]="09:00";b.write_text(json.dumps(data,ensure_ascii=False))
    def call(root,op="load",file="",revision="",stop=0,crash=False):
        p=subprocess.run(["lua5.1",str(driver),str(root),op,str(file),revision,str(stop)],text=True,capture_output=True)
        if crash: assert p.returncode==77,(p.returncode,p.stdout,p.stderr); return
        assert p.returncode==0,(p.returncode,p.stdout,p.stderr)
        return json.loads(p.stdout)
    root=top/"baseline";root.mkdir(mode=0o700)
    first=call(root,"save",a,"empty");assert first["ok"]
    assert call(root)["revision"]==first["revision"]
    assert call(root)["data"]["schedules"][0]["color"]==16
    for stop in range(1,9):
        d=top/("crash-"+str(stop));shutil.copytree(root,d)
        call(d,"save",b,first["revision"],stop,True)
        loaded=call(d);assert loaded["ok"]
        assert loaded["data"]["schedules"][0]["color"]==16
        assert loaded["data"]["schedules"][0]["rows"][0]["time"]==("09:00" if stop>=7 else "08:00")
        result=call(d,"save",b,loaded["revision"]);assert result["ok"]
    # A second real process sees a held lock and cannot modify the file.
    holder=top/"holder.lua";holder.write_text('local f=require("schoolbell.media_fs").new(arg[1],require("schoolbell.media_fs_host"));print("locked");io.stdout:flush();io.read("*l");f.close()')
    p=subprocess.Popen(["lua5.1",str(holder),str(root)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
    try:
        assert p.stdout.readline().strip()=="locked"
        attempt=subprocess.run(["lua5.1",str(driver),str(root),"load"],capture_output=True)
        assert attempt.returncode!=0
    finally:p.communicate("\n",timeout=5)
    assert call(root)["revision"]==first["revision"]
    # Existing special files are refused by the private-root adapter.
    special=top/"special";special.mkdir(mode=0o700);(special/"current.json").symlink_to(a)
    assert not call(special)["ok"]
print("schedule store native: reload, 8 crash checkpoints, process lock, symlink PASS")
