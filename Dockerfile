# Coddy — general-purpose agent in one static Go binary
# https://github.com/coddy-project/coddy-agent
#
# Upstream publishes a `scratch` image, which is the right shape for a laptop
# and the wrong one here: it has no shell, so nothing can validate the
# credentials or prepare the volume before the server starts. This copies the
# static binary out of that image onto a small Alpine base and keeps everything
# else upstream's.
ARG CODDY_VERSION=1.1.32
FROM ghcr.io/coddy-project/coddy-agent:${CODDY_VERSION} AS upstream

FROM alpine:3.22

# ca-certificates for the provider APIs, git for the agent's own use in a
# workspace, tini to reap the tool processes the agent spawns.
RUN apk add --no-cache ca-certificates git tini

COPY --from=upstream /bin/coddy /usr/local/bin/coddy

# PORT is what Railway's healthcheck probes and what the public domain targets,
# so the entrypoint passes it to `coddy serve -P` rather than letting the two
# drift apart.
#
# CODDY_HOME is the whole state directory — sessions, skills, provider
# credentials, trust receipts and the `.env` the binary reads at startup — and
# CODDY_CWD is the workspace the agent works in. Both live on the volume.
#
# No config.yaml is written or required: `coddy serve` starts without one
# (verified), and a provider key in the environment is enough to surface a
# model. Anything further is edited from the web UI, which saves it under
# CODDY_HOME.
ENV PORT=8080 \
    CODDY_HOME=/data/coddy \
    CODDY_CWD=/data/workspace \
    CODDY_CONFIG=/data/coddy/config.yaml \
    CODDY_HTTP_USER=admin

COPY --chmod=755 entrypoint.sh /usr/local/bin/railway-entrypoint

WORKDIR /data/workspace
EXPOSE 8080

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/railway-entrypoint"]
