# Operations

## Updates

Google updates the tagging server image regularly and asks you to keep it current. `./tagdock update` pulls the latest images and recreates the containers whose image changed.

## Unhealthy containers

A tagging server can stay unhealthy after it failed to reach Google, for example during a DNS outage, and Docker does not restart unhealthy containers by itself. `./tagdock heal` restarts every container in the project that Docker reports as unhealthy.

## Cron

Both commands can run from cron.

```cron
*/5 * * * * /opt/tagdock/tagdock heal >/dev/null
30 4 * * 1  /opt/tagdock/tagdock update >/dev/null
```

## What up generates

`./tagdock up` writes `.generated/compose.yaml` and, with Caddy, `.generated/Caddyfile`, then runs `docker compose up`. Every site gets one preview server with `RUN_AS_PREVIEW_SERVER=true` and one tagging server whose `PREVIEW_SERVER_URL` points at the preview domain, as the manual setup guide describes. Google allows exactly one preview server per container, so the preview service is never scaled.

Run `./tagdock render` to write the files without starting anything.
