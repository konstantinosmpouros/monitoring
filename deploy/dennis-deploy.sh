#!/usr/bin/env bash
# Monitoring config sync on Dennis — the ONLY command the monitoring CD key can run.
#
# Installed by the user as /opt/deploy/monitoring.sh (root:root 0755, NOT
# writable by `deployer`) and pinned in ~deployer/.ssh/authorized_keys:
#   command="/opt/deploy/monitoring.sh",no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-pty,no-user-rc ssh-ed25519 AAAA… gha-monitoring
#
# The client's requested command arrives in $SSH_ORIGINAL_COMMAND and must be a
# 40-hex commit sha on origin/main. The script checks it out into the repo clone
# the Swarm stack bind-mounts its configs from, then force-updates ONLY the
# services whose bind-mounted config changed since the last successful deploy
# (recorded as refs/deploy/last in the clone), and waits for them to converge.
# Compose changes are NOT applied here: the CD job calls the Portainer webhook.
#
# Edits to this file reach Dennis only when the user reinstalls it (CLAUDE.md §
# CD to Dennis). See there for the full runbook.
set -euo pipefail
umask 022

readonly REPO=/opt/monitoring/repo
readonly BRANCH=main
readonly STACK=magenticx_monitoring # keep: volumes + service names derive from it
readonly HEALTH_TIMEOUT=300         # seconds per deploy, for every service to converge
readonly ALL_SERVICES="prometheus alertmanager loki alloy grafana"

log() { printf '%s monitoring-deploy: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }
die() {
  log "ERROR: $*" >&2
  exit 1
}

# Map one changed repo path to the Swarm service that reads it (empty = none).
# Single-file bind mounts pin the file's inode, and git replaces files (new
# inode), so a reload can't see the new content: the task must be recreated.
service_for() {
  case "$1" in
    prometheus.yml | alert.rules.yml) echo prometheus ;;
    alertmanager.yml) echo alertmanager ;;
    loki-config.yml | loki-rules.yml) echo loki ;;
    alloy-config.alloy) echo alloy ;;
    grafana/datasources.yml | grafana/dashboards.yml) echo grafana ;;
    *) echo "" ;;
  esac
}

# --- 1. validate the request ---------------------------------------------------
sha="${SSH_ORIGINAL_COMMAND:-}"
if [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
  die "refused: the command must be exactly one 40-hex commit sha"
fi
log "request: deploy $sha"

[[ -d "$REPO/.git" ]] || die "$REPO is not a git clone (one-time setup missing)"
cd "$REPO"

# One deploy at a time.
exec 9>"$REPO/.git/deploy.lock"
flock -w 600 9 || die "another deploy still holds the lock after 10 min"

# --- 2. fetch + verify the sha is on main ---------------------------------------
log "fetch origin/$BRANCH"
git fetch --quiet --prune origin "+refs/heads/$BRANCH:refs/remotes/origin/$BRANCH"
git cat-file -e "${sha}^{commit}" 2>/dev/null || die "refused: $sha is not a commit in origin"
git merge-base --is-ancestor "$sha" "origin/$BRANCH" || die "refused: $sha is not reachable from origin/$BRANCH"

prev="$(git rev-parse --verify --quiet refs/deploy/last || true)"
if [[ -n "$prev" && "$prev" != "$sha" ]] && git merge-base --is-ancestor "$sha" "$prev"; then
  die "refused: $sha is older than the deployed $prev (roll back with a revert commit on $BRANCH)"
fi

if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  die "refused: $REPO has local edits to tracked files; inspect them by hand"
fi

# --- 3. check out --------------------------------------------------------------
log "checkout $sha (previous deploy: ${prev:-none})"
git checkout --quiet --detach "$sha"

# --- 4. decide which services to force-update ----------------------------------
services=""
add_service() {
  case " $services " in *" $1 "*) ;; *) services="${services:+$services }$1" ;; esac
}
if [[ -z "$prev" ]]; then
  log "no previous deploy recorded: updating every config-reading service"
  for s in $ALL_SERVICES; do add_service "$s"; done
else
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    s="$(service_for "$f")"
    if [[ -n "$s" ]]; then
      log "changed: $f -> $s"
      add_service "$s"
    elif [[ "$f" == grafana/dashboards/* ]]; then
      log "changed: $f -> live (Grafana rescans dashboards every 30s)"
    fi
  done < <(git diff --name-only "$prev" "$sha")
fi

# --- 5. force-update + wait for health -------------------------------------------
# Running/desired from `docker service ls`, e.g. "1/1". Global services too.
converged() {
  local reps running desired
  reps="$(docker service ls --filter "name=$1" --format '{{.Name}} {{.Replicas}}' | awk -v n="$1" '$1 == n { print $2 }')"
  [[ "$reps" =~ ^([0-9]+)/([0-9]+) ]] || return 1
  running="${BASH_REMATCH[1]}"
  desired="${BASH_REMATCH[2]}"
  [[ "$desired" -gt 0 && "$running" -eq "$desired" ]]
}

if [[ -z "$services" ]]; then
  log "no bind-mounted config changed: nothing to restart"
else
  for s in $services; do
    log "force-update ${STACK}_$s"
    docker service update --quiet --detach=false --force "${STACK}_$s" >/dev/null
  done

  deadline=$((SECONDS + HEALTH_TIMEOUT))
  for s in $services; do
    until converged "${STACK}_$s"; do
      if ((SECONDS >= deadline)); then
        die "${STACK}_$s did not converge within ${HEALTH_TIMEOUT}s (docker service ps ${STACK}_$s)"
      fi
      sleep 5
    done
    log "healthy: ${STACK}_$s"
  done
fi

# --- 6. record the deploy --------------------------------------------------------
git update-ref refs/deploy/last "$sha"
log "done: deployed $sha"
