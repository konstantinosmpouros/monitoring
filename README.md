# monitoring

Grafana, Prometheus, Loki, Alloy, cAdvisor, node-exporter and Alertmanager for **Dennis**, the shared Oracle Cloud VM. One stack watches every app deployed there, each in its own Grafana folder:

| App | Swarm stack / Compose project | Grafana folder |
| --- | --- | --- |
| mAgenticX | `magenticx` | magenticX |
| OrthodoxAI | `orthodoxai` | OrthodoxAI |

It joins no app network. Logs come from the Docker socket (Alloy → Loki) and container metrics from cgroups (cAdvisor → Prometheus). Alerts go to one Alertmanager that e-mails on Dennis and stays silent locally.

## Run locally

```bash
# once: a Grafana admin password (gitignored)
mkdir -p secrets
python -c "import secrets; open('secrets/grafana_admin_password','w').write(secrets.token_urlsafe(24))"

docker compose up -d     # project `monitoring`; never touches an app container
docker compose down
```

Grafana runs at <http://localhost:3000> as user `admin`. It listens on 127.0.0.1 only and serves plain HTTP. The log panels want `LOG_FORMAT=json` in the app's `.env`.

## Dennis

The Portainer Swarm stack `monitoring` deploys [`docker-compose-denis.yml`](docker-compose-denis.yml). The configs are bind-mounted from `/opt/monitoring/repo/`, a checkout that CD (`.github/workflows/pipeline.yml`) moves to each new commit on `main` over a locked-down SSH key, restarting only the services whose config changed; a compose change also triggers the Portainer webhook. The operational runbook is kept privately.

## Layout

| Path | What |
| --- | --- |
| `docker-compose.yaml` | Local stack |
| `docker-compose-denis.yml` | Dennis Swarm stack |
| `prometheus.yml`, `alert.rules.yml` | Prometheus scrape config + infra/container alerts |
| `loki-config.yml`, `loki-rules.yml` | Loki + LogQL alert rules |
| `alloy-config.alloy` | Docker logs → Loki |
| `alertmanager.yml` | E-mail routing (Dennis) |
| `grafana/` | Datasource + dashboard provisioning, dashboards per app |
| `deploy/dennis-deploy.sh` | The forced-command deploy script CD runs on Dennis |
| `local/` | Local-only discovery (Compose → Swarm label mapping) and a silent Alertmanager |
| `secrets/`, `tls/` | Gitignored: local Grafana password; Dennis Grafana cert + key |
