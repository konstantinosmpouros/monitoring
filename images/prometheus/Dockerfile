# Dennis Prometheus: scrape config + alert rules baked in.
# Built from the repo root: docker build -f images/prometheus/Dockerfile .
FROM prom/prometheus:v3.13.5

COPY prometheus.yml alert.rules.yml /etc/prometheus/
