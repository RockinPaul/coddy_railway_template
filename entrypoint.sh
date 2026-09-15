#!/bin/sh
set -eu

CODDY_HOME="${CODDY_HOME:-/data/coddy}"
WORKSPACE="${CODDY_CWD:-/data/workspace}"
LISTEN_PORT="${PORT:-8080}"

# ---------------------------------------------------------------------------
# Fail closed on missing credentials
# ---------------------------------------------------------------------------
# Coddy's authentication is off by default — upstream's own words — and it logs
# a "reachable without authentication" warning when it binds a non-loopback
# address without a token. On a public Railway domain that warning describes an
# agent with shell access open to anyone who finds the URL, so both gates are
# required here rather than warned about.
#
# The two are not interchangeable: the token closes /v1/* and /coddy/* for API
# clients, and the sign-in form is the browser's credential for the same gate.
# Without the token the API is open; without the password the web UI cannot be
# used at all, because the SPA has no field to type a token into.
if [ -z "${CODDY_HTTP_TOKEN:-}" ] || [ "$(printf '%s' "${CODDY_HTTP_TOKEN}" | wc -c)" -lt 16 ]; then
    echo "FATAL: CODDY_HTTP_TOKEN is empty or shorter than 16 characters." >&2
    echo "  It is the bearer token for /v1/* and /coddy/*; without it the agent's" >&2
    echo "  API is open to anyone who finds this URL. The template generates one." >&2
    exit 1
fi
if [ -z "${CODDY_HTTP_PASSWORD:-}" ] || [ "$(printf '%s' "${CODDY_HTTP_PASSWORD}" | wc -c)" -lt 12 ]; then
    echo "FATAL: CODDY_HTTP_PASSWORD is empty or shorter than 12 characters." >&2
    echo "  It is the web UI sign-in for '${CODDY_HTTP_USER:-admin}'. The template" >&2
    echo "  generates one; read it from the service variables." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Volume layout
# ---------------------------------------------------------------------------
# Railway mounts the volume root-owned with a lost+found directory, so state
# lives in subdirectories beside it. Coddy runs as root here — the image drops
# no privileges — so HOME does not need the passwd indirection other templates
# use, but it does have to point at the volume or every session is lost on the
# next deploy.
mkdir -p "${CODDY_HOME}" "${WORKSPACE}"

echo "coddy: state at ${CODDY_HOME}, workspace at ${WORKSPACE}"
echo "coddy: serving on :${LISTEN_PORT} with bearer auth and web sign-in as '${CODDY_HTTP_USER:-admin}'"

# `-H ::` is a dual-stack listener on Go's runtime — measured: both 127.0.0.1
# and [::1] answer — which serves Railway's edge and the IPv6-only private
# network from one socket, with no relay in front.
exec coddy serve -H :: -P "${LISTEN_PORT}" "$@"
