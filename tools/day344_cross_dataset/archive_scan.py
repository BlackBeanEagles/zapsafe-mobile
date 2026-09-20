"""Deep-scan every archive across all drives: what is actually inside each one."""
import os, sys, zipfile, tarfile, collections, json
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
ROOTS=[r"C:\Users\hridy\Desktop\zapsafe", r"C:\Users\hridy\Desktop\dsfolder",
       r"D:\zapsafe", r"E:\datasets", r"F:\zapsafe"]
EXT=(".zip",".tar",".tar.gz",".tgz",".rar",".7z")
out=[]
def names_zip(p,lim=3000):
    z=zipfile.ZipFile(p); n=z.namelist()[:lim]; z.close(); return n
def names_tar(p,lim=3000):
    t=tarfile.open(p,"r|*"); n=[]
    for i,m in enumerate(t):
        n.append(m.name)
        if i>=lim: break
    t.close(); return n
for root in ROOTS:
    if not os.path.isdir(root): continue
    for dp,_,fns in os.walk(root):
        if ".git" in dp or "__pycache__" in dp: continue
        for fn in fns:
            low=fn.lower()
            if not low.endswith(EXT): continue
            p=os.path.join(dp,fn)
            try: size=os.path.getsize(p)
            except OSError: continue
            rec={"path":p,"size":size,"entries":None,"types":{},"top":[],"err":None}
            try:
                if low.endswith(".zip"): n=names_zip(p)
                elif low.endswith((".tar",".tar.gz",".tgz")): n=names_tar(p)
                else: n=None; rec["err"]="rar/7z (no reader)"
                if n is not None:
                    rec["entries"]=len(n)
                    c=collections.Counter(x.rsplit(".",1)[-1].lower() for x in n
                                          if "." in x and not x.endswith("/"))
                    rec["types"]=dict(c.most_common(6))
                    rec["top"]=sorted({x.split("/")[0] for x in n})[:5]
            except Exception as e:
                rec["err"]=f"{type(e).__name__}: {str(e)[:60]}"
            out.append(rec)
            print(f"{size/1e6:9.0f}MB {os.path.basename(p)[:44]:46s} "
                  f"{rec['entries'] if rec['entries'] is not None else '-':>6} "
                  f"{list(rec['types'])[:4]} {rec['err'] or ''}", flush=True)
json.dump(out, open(r"C:\Users\hridy\Desktop\zapsafe\work\archive_scan.json","w"), indent=1)
print(f"\nscanned {len(out)} archives")
