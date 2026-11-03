# Dennis Alertmanager: e-mail routing baked in; the SMTP password is a Swarm
# secret read at runtime.
# Built from the repo root: docker build -f images/alertmanager/Dockerfile .
FROM prom/alertmanager:v0.34.1

COPY alertmanager.yml /etc/alertmanager/alertmanager.yml
