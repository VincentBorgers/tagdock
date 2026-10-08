# Configuration

## tagdock.env

`tagdock.env` holds the settings for the whole server. Copy it from [tagdock.env.example](../tagdock.env.example).

| Setting | Default | |
| --- | --- | --- |
| `PROXY` | `caddy` | `caddy` or `none`. With `none` you run your own reverse proxy, see [nginx.md](nginx.md) |
| `ACME_EMAIL` | | Email for Let's Encrypt expiry notices |
| `LISTEN_ADDRESS` | all interfaces, or `127.0.0.1` with `PROXY=none` | Address the published ports bind to |
| `HTTP_PORT`, `HTTPS_PORT` | `80`, `443` | Ports Caddy publishes |
| `CADDY_LOCAL_CERTS` | `false` | Use Caddy's internal CA instead of Let's Encrypt, for testing |
| `COMPOSE_PROJECT` | `tagdock` | Compose project name. Change it to run more than one copy on a host |
| `SGTM_IMAGE` | `gcr.io/cloud-tagging-10302018/gtm-cloud-image:stable` | Tagging server image |
| `CADDY_IMAGE` | `caddy:2` | Caddy image |

## Site files

Each file in `sites/` is one GTM server container. `./tagdock add <site>` asks for the values and creates the file. `./tagdock add <site> --template` copies [the template](../sites/example.env.template) so you can fill it in yourself.

| Setting | Required | |
| --- | --- | --- |
| `CONTAINER_CONFIG` | always | Container Config from Tag Manager |
| `PREVIEW_DOMAIN` | always | Domain of the preview server |
| `TAGGING_DOMAIN` | with `PROXY=caddy` | Domain of the tagging server |
| `TAGGING_PORT`, `PREVIEW_PORT` | with `PROXY=none` | Ports your reverse proxy forwards to |
| `TAGGING_MEMORY`, `PREVIEW_MEMORY` | no | Memory limits, `1g` and `512m` by default |

Google's guide says a tagging server uses at most one vCPU, so there is no CPU setting.

The site files contain your container configs. They are ignored by git and created with mode 600, and the files in `.generated/` refer to them instead of copying the values.

## Checks

`./tagdock check` validates every file and prints the GTM container ID each `CONTAINER_CONFIG` belongs to, so you can see that a site file holds the config you meant to paste.

It also looks up every domain and warns when it does not resolve or resolves to an address this server does not have. `./tagdock add` and `./tagdock up` show the same warnings. They never stop the command, because a proxy such as Cloudflare or a NAT gateway in front of the server is a valid reason for a different address.
