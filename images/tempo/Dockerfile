# Dennis Tempo: config baked in; traces live in the tempo-data volume.
# Built from the repo root: docker build -f images/tempo/Dockerfile .
FROM grafana/tempo:2.10.10

COPY tempo-config.yml /etc/tempo/tempo.yml
