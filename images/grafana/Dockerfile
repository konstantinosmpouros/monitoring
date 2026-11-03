# Dennis Grafana: the datasources, the dashboard providers and every app's
# dashboards are baked in (they were bind-mounts). The TLS pair stays on the
# host (/opt/monitoring/tls) and the admin password is a Swarm secret.
# Built from the repo root: docker build -f images/grafana/Dockerfile .
FROM grafana/grafana:12.4.14

ARG APP_VERSION=dev

COPY grafana/datasources.yml /etc/grafana/provisioning/datasources/monitoring.yml
COPY grafana/dashboards.yml /etc/grafana/provisioning/dashboards/monitoring.yml
COPY grafana/dashboards/ /etc/grafana/dashboards/

# The release tag, served at /public/monitoring-version.txt: CD waits until
# the live Grafana reports it.
USER root
RUN printf '%s\n' "$APP_VERSION" > /usr/share/grafana/public/monitoring-version.txt
USER 472
