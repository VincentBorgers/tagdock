<p align="center"><img src="assets/logo.svg" width="96" alt=""></p>

# tagdock

[![CI](https://github.com/VincentBorgers/tagdock/actions/workflows/ci.yml/badge.svg)](https://github.com/VincentBorgers/tagdock/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/VincentBorgers/tagdock)](LICENSE)
[![Buy me a coffee](https://img.shields.io/badge/Buy_me_a_coffee-FFDD00?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/vincentborgers)

Run server-side Google Tag Manager on your own server with Docker Compose.

tagdock follows Google's [manual setup guide](https://developers.google.com/tag-platform/tag-manager/server-side/manual-setup-guide) for running the tagging server outside Google Cloud and wraps it in one script.

## Features

- A preview server and a tagging server for every GTM server container, as Google describes
- HTTPS with Let's Encrypt through Caddy, or your own nginx in front
- Several containers on one server, for example one per client
- `heal` restarts tagging servers that got stuck, `update` pulls the latest image

## Quick start

You need a Linux server with Docker and the Compose plugin, ports 80 and 443 free, and two DNS records per container that point to it, for example `sgtm.example.com` and `sgtm-preview.example.com`.

Copy the Container Config from Tag Manager first. Open the server container workspace, click the container ID and choose **Manually provision tagging server**.

```sh
git clone https://github.com/VincentBorgers/tagdock.git
cd tagdock
cp tagdock.env.example tagdock.env
./tagdock add shop
./tagdock up
```

`./tagdock add` asks for the Container Config and both domains, and warns when a domain does not point to the server yet. After `./tagdock up`, `https://sgtm.example.com/healthy` should return `ok`.

## Connect Tag Manager

1. In the server container, go to **Admin > Container Settings** and add `https://sgtm.example.com` under **Server container URLs**.
2. In the web container, set the `server_container_url` parameter of your Google tag to `https://sgtm.example.com`. See Google's guide on [sending data to server-side Tag Manager](https://developers.google.com/tag-platform/tag-manager/server-side/send-data).

## Commands

| Command | What it does |
| --- | --- |
| `./tagdock add <site>` | Ask for the values and create `sites/<site>.env` |
| `./tagdock check` | Validate the configuration and check the DNS records |
| `./tagdock up` | Start or update the containers |
| `./tagdock status` | Show the state and health of every container |
| `./tagdock update` | Pull the latest images and recreate what changed |
| `./tagdock heal` | Restart containers that are unhealthy |
| `./tagdock logs <site> [tagging\|preview]` | Follow the logs of a site |
| `./tagdock down` | Stop and remove the containers |

## Documentation

- [Configuration](docs/configuration.md) lists every setting in `tagdock.env` and the site files
- [Running behind nginx](docs/nginx.md) covers servers that already have a reverse proxy
- [Operations](docs/operations.md) explains updates, `heal`, cron and what `up` generates

tagdock does not contain any Google code. It pulls the tagging server image from Google's registry, and running that image is subject to the [Google Tag Manager terms of service](https://www.google.com/analytics/terms/tag-manager/).

## Contributing

Bug reports and pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before you open a pull request.

## License

[MIT](LICENSE)
