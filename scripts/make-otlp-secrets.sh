#!/usr/bin/env bash
# Creates the OTLP ingest secrets in secrets/ (gitignored), for the local stack
# and as the source of the Dennis Swarm secrets:
#
#   secrets/otlp_ca.key, otlp_ca.crt     private "monitoring OTLP CA" (10 years).
#                                        The .crt goes to every app (Phase B) so it
#                                        can verify the collector; the .key stays
#                                        here, offline, and never goes to Dennis.
#   secrets/otlp_tls.key, otlp_tls.crt   alloy-otlp's server cert (2 years),
#                                        SANs alloy-otlp, monitoring_alloy-otlp,
#                                        tasks.alloy-otlp, localhost.
#   secrets/otlp_bearer_token            the token every app presents (32 bytes).
#
# Existing files are never overwritten: delete the ones to rotate first.
# Run from the repo root:  bash scripts/make-otlp-secrets.sh
set -euo pipefail

cd "$(dirname "$0")/.."
umask 077
mkdir -p secrets
cd secrets

# Git Bash on Windows rewrites "/CN=..." into a path without this.
export MSYS_NO_PATHCONV=1

if [ ! -f otlp_ca.key ]; then
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
    -keyout otlp_ca.key -out otlp_ca.crt -days 3650 \
    -subj "/CN=monitoring OTLP CA" \
    -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
    -addext "keyUsage=critical,keyCertSign,cRLSign"
  echo "created otlp_ca.{key,crt}"
fi

if [ ! -f otlp_tls.key ]; then
  openssl req -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
    -keyout otlp_tls.key -out otlp_tls.csr -subj "/CN=alloy-otlp"
  cat > otlp_tls.ext <<'EOF'
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature
extendedKeyUsage=serverAuth
subjectAltName=DNS:alloy-otlp,DNS:monitoring_alloy-otlp,DNS:tasks.alloy-otlp,DNS:localhost
EOF
  openssl x509 -req -in otlp_tls.csr -CA otlp_ca.crt -CAkey otlp_ca.key \
    -CAcreateserial -out otlp_tls.crt -days 730 -extfile otlp_tls.ext
  rm -f otlp_tls.csr otlp_tls.ext otlp_ca.srl
  echo "created otlp_tls.{key,crt}"
fi

if [ ! -f otlp_bearer_token ]; then
  # No trailing newline / CR (openssl on Windows ends lines with CRLF): the
  # token is compared byte for byte, and gRPC rejects a CR in a header.
  openssl rand -hex 32 | tr -d '\r\n' > otlp_bearer_token
  echo "created otlp_bearer_token"
fi

# The containers run as nobody (local Compose bind-mounts these files).
chmod 0644 otlp_tls.crt otlp_tls.key otlp_bearer_token otlp_ca.crt
chmod 0600 otlp_ca.key
openssl verify -CAfile otlp_ca.crt otlp_tls.crt
