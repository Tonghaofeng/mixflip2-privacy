import json,subprocess,time,collections,re,sys
E='/Users/Tony/Documents/MixFlip2-debloat/evidence/health_20261001'
PHONE='192.168.50.184'; DUR=int(sys.argv[1]); t0=time.time(); seen={}
CLI="/Applications/Surge.app/Contents/Applications/surge-cli --raw dump"
while time.time()<t0+DUR:
    for kind in ("recent","active"):
        try:
            raw=subprocess.run(["ssh","-o","BatchMode=yes","-o","ConnectTimeout=8","macserver",f"{CLI} {kind}"],capture_output=True,text=True,timeout=25).stdout
            for r in json.loads(raw).get("requests",[]):
                if r.get("sourceAddress")==PHONE and r.get("startDate",0)>=t0-5: seen[r["id"]]=r
        except Exception as e: pass
    time.sleep(8)
json.dump(list(seen.values()),open(E+'/surge_phone_direct_poll.json','w'),indent=1,default=str)
ALLOWED=re.compile(r":(51820|123)$|^(223\.5\.5\.5|1\.12\.12\.12):443$")
print(f"window {time.strftime('%H:%M:%S',time.localtime(t0))} +{DUR}s; new conns from phone Wi-Fi IP: {len(seen)}")
c=collections.Counter((r.get('remoteHost') or r.get('URL'), r.get('policyName'), r.get('rule'), r.get('outBytes'), r.get('inBytes')) for r in seen.values())
for k,v in c.most_common(30): print(v,k,"" if ALLOWED.search(str(k[0])) else "<-- not whitelisted")
