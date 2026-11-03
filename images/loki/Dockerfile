# Dennis Loki: config + LogQL alert rules baked in (tenant "fake": auth off).
# Built from the repo root: docker build -f images/loki/Dockerfile .
FROM grafana/loki:3.7.8

COPY loki-config.yml /etc/loki/loki-config.yml
COPY loki-rules.yml /etc/loki/rules/fake/rules.yml
