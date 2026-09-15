# Deploy and Host Coddy on Railway

[Coddy](https://github.com/coddy-project/coddy-agent) is a general-purpose AI agent in a single
static Go binary. One process serves a web UI, an OpenAI-compatible HTTP API, a cron scheduler and a
remote mode, all sharing the same sessions — so a conversation started in the browser can be
continued from your terminal or your editor.

This template runs it on Railway with its sessions and workspace on a volume, behind a password and
a bearer token generated for your deployment. One service, one volume, a public domain.

## About Hosting Coddy

Coddy is a ReAct agent with filesystem and shell tools, MCP servers, rules, skills, subagents,
hooks, background tasks, long-term memory and context compaction. It works with any
OpenAI-compatible provider — OpenAI, Anthropic, Ollama, llama.cpp, vLLM and others — so nothing is
proxied through a third party.

Because upstream ships a static binary, the deployed image is about 57 MB and starts in a few
seconds. Everything it owns lives on the volume: sessions, skills, provider credentials, scheduler
jobs and the workspace the agent edits. No configuration file is needed to start — a provider key is
enough for a model to appear — and anything further is edited from the web UI, which saves it to the
volume.

The two credentials are the part this template takes seriously. Coddy's authentication is off by
default and it warns when it binds a public address without a token; on a Railway domain that
describes an agent with shell access reachable by anyone who finds the URL. So both a browser
password and an API bearer token are generated for your deployment, and the container refuses to
start without them.

## Why Deploy Coddy on Railway?

- **It stays awake.** Scheduled jobs and long agent runs keep going with no machine of your own left
  running.
- **One service, no assembly.** No database, queue or second container.
- **Reachable from everywhere, as one agent.** Browser, any OpenAI-compatible client, your terminal
  over `coddy --remote`, or an editor over ACP — all on the same sessions.
- **Your own provider.** Bring any OpenAI-compatible key; usage is between you and that provider.
- **It survives redeploys.** Sessions, skills, credentials and the workspace are on the volume.

## Common Use Cases

- A always-on coding agent you can reach from a laptop, a phone browser or a borrowed machine.
- Scheduled work: cron jobs written as Markdown, each run its own session.
- An OpenAI-compatible endpoint for your own scripts and tools, backed by an agent rather than a
  bare model.
- A remote backend for your editor over the Agent Client Protocol.
- A shared long-running workspace where sessions started in one surface continue in another.

## Dependencies for Coddy Hosting

- A model provider — an OpenAI-compatible API key, Anthropic, or any endpoint you configure in the
  web UI.
- Nothing else: no database, no external services, no accounts.

### Deployment Dependencies

- Upstream project: <https://github.com/coddy-project/coddy-agent> (MIT), image
  `ghcr.io/coddy-project/coddy-agent:1.1.32`.
- Upstream documentation: <https://github.com/coddy-project/coddy-agent/tree/main/docs>.
- Template source: <https://github.com/RockinPaul/coddy_railway_template> (MIT).

### Implementation Details

**After deploying:** copy `CODDY_HTTP_PASSWORD` from the service's Variables tab, open the public
domain, and sign in as **`admin`**. Then set `OPENAI_API_KEY` (or add a provider in the UI) and pick
a model.

**Why the credentials are generated secrets.** Coddy's own default is no authentication, which is
correct for a binary listening on loopback and wrong for a public URL. This template generates both
credentials per deployment so they are visible in the Variables tab the moment the deploy finishes,
and the container fails to start if either is missing or too short — there is no path to an
unprotected instance. `CODDY_HTTP_PASSWORD` is hashed with argon2id at startup and never written to
disk in plaintext; upstream deliberately offers no command-line flag for it, since a password on a
command line is visible in `ps`.

Use `CODDY_HTTP_TOKEN` to drive this deployment from elsewhere:

```
coddy --remote your-app.up.railway.app:443 --remote-token "$CODDY_HTTP_TOKEN"
```

**Security.** Measured against a running instance: `/v1/*` and `/coddy/*` return 401 without a token
and with a wrong one, the browser sign-in returns 401 on a wrong password and sets an
`HttpOnly; SameSite=Strict` cookie on the right one, and a cross-site sign-in attempt is refused
with 403. The honest caveat: this is an agent with shell and filesystem tools, so the blast radius
of the URL is a shell in this container — keep the generated credentials and treat the link like an
SSH session into a dev box.

**Notes.** `PORT` is 8080 and the server follows it; Railway's healthcheck probes that port and the
domain targets it, so leave it as is. Health is the SPA shell at `/`, which stays public by design.
The published upstream image is built without the `gateway` tag, so the Telegram gateway is not
available here. Upstream releases very often — pin `CODDY_VERSION` deliberately rather than
tracking `latest`.

## Licences

Coddy is MIT. The template's glue is MIT.
