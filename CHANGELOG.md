# Changelog

## 0.1.0

First release.

- `tagdock` script with the commands `add`, `check`, `render`, `up`, `status`, `update`, `heal`, `logs` and `down`
- `add` asks for the Container Config and domains, and `--template` creates the file without questions
- DNS check in `add`, `check` and `up` that warns when a domain does not point to the server
- One preview server and one tagging server per GTM server container
- HTTPS through Caddy, or published on `127.0.0.1` for your own reverse proxy
- Example nginx configuration
