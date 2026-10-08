# Running behind nginx

Use this when nginx already serves ports 80 and 443 on the server.

Set `PROXY=none` in `tagdock.env` and give each site two free ports.

```sh
# tagdock.env
PROXY=none
```

```sh
# sites/shop.env
CONTAINER_CONFIG=...
PREVIEW_DOMAIN=sgtm-preview.example.com
TAGGING_PORT=18080
PREVIEW_PORT=18081
```

After `./tagdock up` the tagging server listens on `127.0.0.1:18080` and the preview server on `127.0.0.1:18081`. They are not reachable from outside the server.

Add one server block per domain. Google's guide asks for a proxy timeout longer than 20 seconds, which `proxy_read_timeout 60s` covers. The certificate paths below are the ones certbot uses.

```nginx
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name sgtm.example.com;

    ssl_certificate     /etc/letsencrypt/live/sgtm.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/sgtm.example.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:18080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 60s;
    }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name sgtm-preview.example.com;

    ssl_certificate     /etc/letsencrypt/live/sgtm-preview.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/sgtm-preview.example.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:18081;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 60s;
    }
}
```

Run `nginx -t` and reload nginx. `https://sgtm.example.com/healthy` should then return `ok`.
