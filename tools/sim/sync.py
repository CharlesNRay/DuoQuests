import os,re,shutil,sys
HERE=os.path.dirname(os.path.abspath(__file__))
SRC=os.path.join(HERE,"..","..","src")
OUT=os.path.join(HERE,".build","hl6")
shutil.rmtree(OUT,ignore_errors=True); os.makedirs(OUT, exist_ok=True)  # the folder may be held open (a shell inside it): reuse it
def tr(text,reldir):
    def rep(m):
        parts=m.group(1).split(".")  # script, Parent, [Parent..], names
        assert parts[0]=="script" and parts[1]=="Parent"
        i=1; ups=0
        while i<len(parts) and parts[i]=="Parent": i+=1
        ups=i-2; rest=parts[i:]
        return 'require("%s%s")'%("./"+"../"*ups if ups==0 else "../"*ups,"/".join(rest))
    text=re.sub(r'require\((script(?:\.Parent)+(?:\.\w+)*)\)',rep,text)
    text=re.sub(r'require\(game:GetService\("ReplicatedStorage"\):WaitForChild\("Shared"\):WaitForChild\("(\w+)"\)\)',r'require("./\1")',text)
    return text
def put(srcpath,rel):
    t=open(srcpath,encoding="utf-8").read()
    dst=os.path.join(OUT,rel); os.makedirs(os.path.dirname(dst),exist_ok=True)
    open(dst,"w",encoding="utf-8",newline="").write(tr(t,os.path.dirname(rel)))
for root,_,files in os.walk(SRC+"/shared"):
    for f in files:
        if f.endswith(".luau"):
            p=os.path.join(root,f); put(p,os.path.relpath(p,SRC+"/shared"))
for f in os.listdir(SRC+"/server/Tests"):
    put(SRC+"/server/Tests/"+f,f)
put(SRC+"/server/Services/PartyCore.luau","PartyCore.luau")
put(SRC+"/server/Data/CodeList.luau","CodeList.luau")
# DataService as a factory for the headless save tests (DataServiceTests): the Roblox services it touches are
# parameters, so a test can start two fake servers that share one fake DataStore.
_ds = open(SRC + "/server/Services/DataService.luau", encoding="utf-8").read()
_ds = re.sub(r'require\(Shared\.Config\.(\w+)\)', r'require("./Config/\1")', _ds)
_ds = re.sub(r'require\(Shared\.Util\.(\w+)\)', r'require("./Util/\1")', _ds)
_ds = re.sub(r'require\(Shared\.(\w+)\)', r'require("./\1")', _ds)
open(os.path.join(OUT, "DataServiceSim.luau"), "w", encoding="utf-8", newline="").write(
    "return function(game, task, warn, os)\n" + _ds + "\nend\n")
