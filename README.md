# Coddy on Railway

[Coddy](https://github.com/coddy-project/coddy-agent) — a general-purpose AI agent in one static Go
binary, with a web UI, an OpenAI-compatible API, a cron scheduler and remote mode — running on
Railway with its sessions and workspace on a volume, behind a generated password and bearer token.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/coddy)

## Service

| Service | Base | Public | Role |
|---|---|---|---|
| `coddy` | `alpine:3.22` + `coddy` 1.3.63 | **yes** | The whole agent: web UI, `/v1/*` API, scheduler, sessions. |

One service, one volume, no gateway. `coddy serve` runs every subsystem in one process, and the
image is 57 MB because upstream ships a static Go binary.

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `CODDY_HTTP_PASSWORD` | generated, 24 chars | Web UI sign-in for `admin`. Read it from the service variables after deploying. |
| `CODDY_HTTP_TOKEN` | generated, 32 chars | Bearer token for `/v1/*` and `/coddy/*` — API clients, `coddy --remote`, editors over ACP. |
| `OPENAI_API_KEY` | *(empty)* | Optional. A provider key is all it takes to get a model; any `<NAME>_API_KEY` works for a provider called `<name>`. |
| `PORT` | `8080` | The port Railway's healthcheck probes and the domain targets. Leave it alone. |
| `CODDY_HTTP_USER` | `admin` | Baked. Add the variable to change the sign-in name. |
| `CODDY_HOME` | `/data/coddy` | Baked. Sessions, skills, provider credentials and `.env` on the volume. |
| `CODDY_CWD` | `/data/workspace` | Baked. The workspace the agent works in, on the volume. |

The deploy form asks for nothing you have to invent.

## First run

1. Copy `CODDY_HTTP_PASSWORD` from the service's **Variables** tab.
2. Open the public domain and sign in as **`admin`**.
3. Add a provider key — `OPENAI_API_KEY` as a service variable, or any provider from the web UI,
   which saves it under `CODDY_HOME` on the volume.

No `config.yaml` is required: `coddy serve` starts without one, and a provider key in the
environment is enough for a model to appear in the picker. Everything beyond that is edited from the
UI or by putting a `config.yaml` on the volume at `/data/coddy/config.yaml`.

To drive this deployment from your own terminal or editor, point them at it with the bearer token:

```bash
coddy --remote your-app.up.railway.app:443 --remote-token "$CODDY_HTTP_TOKEN"
```

## Security

Both gates are **required** here, which is stricter than upstream's default — and deliberately so.
Coddy's authentication is off by default, and it logs a "reachable without authentication" warning
when it binds a non-loopback address without a token. On a public domain that warning describes an
agent with shell access open to anyone who finds the URL, so the entrypoint refuses to start without
both credentials.

Measured against a running instance, not taken from the docs:

- `/v1/models` returns **401** with no token and **401** with a wrong one; **200** with the right
  one. `/docs` and `/openapi.json` are gated too.
- The browser sign-in returns **401** on a wrong password and **200** on the right one, setting an
  `HttpOnly; SameSite=Strict` session cookie.
- A cross-site sign-in attempt is refused with **403 `cross-site sign-in refused`** — CSRF is
  handled upstream, not by this template.
- `CODDY_HTTP_PASSWORD` is hashed with **argon2id** as the server starts and never written into
  `config.yaml`. Upstream deliberately provides no command-line flag for it, "because a password on
  a command line is visible in `ps`".

The honest caveat: this is an agent with filesystem and shell tools. The blast radius of the URL is
a shell in this container. Keep the generated credentials, and treat the link accordingly. Upstream
ships operating modes (`agent`, `plan`, `ask`), permission prompts and project trust for what
arrives with a checkout — see [Security and trust](https://github.com/coddy-project/coddy-agent/blob/main/docs/operate/security.md).

## What persists

The volume at `/data` holds `coddy/` — sessions, skills, provider credentials, scheduler jobs, trust
receipts — and `workspace/`, the tree the agent works in. Verified by replacing the container: both
files written before the swap were there afterwards, and the sign-in still worked.

## Why it is shaped this way

- **A shell base instead of upstream's `scratch` image.** The published image is `scratch`, which is
  right for a laptop and wrong here: with no shell, nothing can validate the credentials or prepare
  the volume before the server starts. The static binary is copied out of it onto Alpine.
- **`-H ::` with no relay.** Go binds dual-stack on `::` — measured, both `127.0.0.1` and `[::1]`
  answer — so unlike the Python services in this portfolio, no `socat` is needed in front.
- **`PORT` is a real variable.** Railway's healthcheck probes the port named by `PORT`, not the
  domain's target port, so the entrypoint passes it to `coddy serve -P`.
- **`restartPolicyType: ALWAYS`.** A clean `SIGTERM` exits `0`, which `ON_FAILURE` would not
  restart. For a server that should never exit on its own, `ALWAYS` is the correct policy.
- **Healthcheck on `/`.** The SPA shell stays public by design so a client can load and prompt for
  credentials, so it answers 200 unauthenticated — including with Railway's
  `Host: healthcheck.railway.app`.

## Known limits

The published image is built with the `http`, `scheduler`, `ui`, `memory`, `cli`, `gateway` and
`swarm` build tags (upstream's `docker-build-push.yaml`), so the Telegram gateway, the swarm relay
and the scheduler are all compiled in; each is switched on from `config.yaml`. An earlier version of
this README said the gateway was missing, which was not the case.

## Upgrading

Bump `CODDY_VERSION` in the `Dockerfile` and push. Upstream releases very often — several times a
day at the moment — so pin deliberately rather than tracking `latest`.

## Licences

Coddy is [MIT](https://github.com/coddy-project/coddy-agent/blob/main/LICENSE). The glue in this
repository is MIT as well.
