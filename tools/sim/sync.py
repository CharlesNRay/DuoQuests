import os,re,shutil,sys
HERE=os.path.dirname(os.path.abspath(__file__))
SRC=os.path.join(HERE,"..","..","src")
OUT=os.path.join(HERE,".build","hl6")
shutil.rmtree(OUT,ignore_errors=True); os.makedirs(OUT)
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
