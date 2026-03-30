#Error response from daemon: failed to resolve reference ... TLS handshake timeout  
solved:
```
nano /etc/docker/daemon.json
```
```
{
  "registry-mirrors": [
    "https://mirror.gcr.io",
    "https://daocloud.io",
    "https://c.163.com"
  ]
}
```
