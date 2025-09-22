KaTrain → Settings → Engine:
- Engine type: KataGo JSON (socket)
- Host: 127.0.0.1
- Port: 2388
- Model: point to your .bin.gz in models/ (KaTrain can also reference the same file)

KaTrain uses KataGo’s JSON analysis engine and can connect over a socket. 
Refs: KaTrain maintainer notes + issue thread about remote engines. 
