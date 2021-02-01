#!/usr/bin/env python3
import requests

g=requests.get('https://github.com/rancher/rke/releases/download/v1.0.4/rke_linux-amd64')
print(g.status_code)
print(g.url)
print(len(g.content))
f=open('/tmp/foo','w')
f.write(str(g.content))
f.close()
