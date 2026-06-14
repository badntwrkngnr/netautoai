# Infrahub stack

Infrahub's full stack (Neo4j/Memgraph, RabbitMQ message queue, Prefect-based
task manager, server, and task-worker -- ~9 containers) is generated and
published upstream and changes between releases. Rather than maintain a
hand-written copy here that drifts out of date, this directory fetches the
official compose file and layers a small override on top.

## Setup

```bash
cd stacks/infrahub
./fetch-base-compose.sh
cp .env.example .env   # then edit with real secrets
docker compose -f docker-compose.yml -f docker-compose.override.yml up -d
```

## What the override does

`docker-compose.override.yml` attaches the Infrahub server and task-worker
containers to `automation_net`, the network shared with Traefik, Netbox,
Zabbix, and Grafana, and adds Traefik labels so the server is reachable on
`http://netautoai:8083`. This lets:

- Traefik route to `infrahub-server` on port 8000
- Your Netbox -> Infrahub sync script (in `scripts/`) reach both
  `netbox:8080` and `infrahub-server:8000` by name

## Things to check after fetching

- Confirm the server/worker service names match what's referenced in
  `docker-compose.override.yml` (these have been renamed before -- the git
  agent service became "task-worker").
- Confirm the internal port Infrahub's server listens on (currently 8000)
  matches the `traefik.http.services.infrahub.loadbalancer.server.port`
  label.
- Review resource usage -- this is the heaviest stack in the project.
