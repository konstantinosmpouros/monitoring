# Dennis Alloy: both configs baked in, one image for two services —
#   alloy       config.alloy  Docker logs → Loki (root, Docker socket)
#   alloy-otlp  otlp.alloy    OTLP collector → Tempo / Prometheus / Loki
#                             (non-root, no socket, on the observability net)
# Built from the repo root: docker build -f images/alloy/Dockerfile .
FROM grafana/alloy:v1.20.1

COPY alloy-config.alloy /etc/alloy/config.alloy
COPY alloy-otlp.alloy /etc/alloy/otlp.alloy
