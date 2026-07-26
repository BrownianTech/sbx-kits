# claude-code-rc-shim kit

A Docker Sandboxes mixin kit that makes **Claude Code Remote Control (RC)**
work correctly inside an sbx sandbox.

## The problem

Inside a sandbox, sbx's forward proxy rewrites the `Authorization` header
unconditionally to inject your Anthropic credential. This is correct for
normal inference, but RC's **worker / work-lease / transcript** planes use
**per-session scoped tokens** — not the OAuth token — so the rewrite clobbers
them and the RC worker fails to register (`401` / `403` /
`worker_register_failed`).

See [cbrown1234/sbx-claude-code-rc-shim](https://github.com/cbrown1234/sbx-claude-code-rc-shim)
for the full explanation and upstream issue reference.

## Vendored source

The shim's scripts (`setup.sh`, `run.sh`, `rc-claude.sh`, `addon.py`) live in
this kit's [`files/home/scoped-token-shim/`](files/home/scoped-token-shim/),
copied verbatim to `~/scoped-token-shim/` when the kit is applied — no
runtime `git clone` from GitHub, so `github.com` isn't in this kit's network
caps.

They were vendored via `git subtree` from
[cbrown1234/sbx-claude-code-rc-shim@df47e06](https://github.com/cbrown1234/sbx-claude-code-rc-shim/commit/df47e06)
(`main`). To pull in upstream fixes later:

```console
git subtree pull --prefix=claude-code-rc-shim/files/home/scoped-token-shim \
  https://github.com/cbrown1234/sbx-claude-code-rc-shim.git main --squash
```

## What this kit does

A single `commands.startup` hook (`background: true`) runs the vendored
`setup.sh`, symlinks `rc-claude.sh` onto `PATH` as `rc-claude`, and starts
`run.sh` in the background — all on every sandbox boot. `setup.sh`:

1. Installs `mitmproxy` (isolated, via `uv tool install --python 3.12`)
2. Generates mitmproxy's CA cert (brief headless run)
3. Appends the CA to `/etc/ssl/certs/ca-certificates.crt` so node, python,
   and curl all trust the shim's TLS interception

Everything runs from `commands.startup` rather than `commands.install`:
kit-provided files (`files/home/`) aren't mounted into the container until
the startup phase, so an install step can't see `setup.sh` at all — it runs
before the mount and fails with "not found".

Once `run.sh`'s `mitmdump` is confirmed actually listening on
`127.0.0.1:8080`, the startup hook appends `HTTP(S)_PROXY`
(upper- and lower-case) overrides to `/etc/sandbox-persistent.sh`, which
every login shell sources (and which is exported as `BASH_ENV` for
non-interactive bash children) — so a plain `claude` picks up the shim
without needing the `rc-claude` wrapper. This was tried first as a
container-level `environment.variables` override instead, which is
inherited unconditionally by every process including other kits'
`commands.install` steps — it broke `gitlab-api`'s install, which needs
real internet egress before the shim exists to route through. Gating the
publish on shim readiness avoids both that and ever pointing a new shell
at a proxy that isn't up yet.

No credentials are declared — the shim works entirely at the network layer.

## Usage

After the kit is applied, inside the sandbox:

```console
# 1. Launch Claude Code as normal -- already routed through the shim
claude

# 2. Inside Claude Code, start a remote-control session
/remote-control
```

If you attach right as the sandbox starts, `uv tool install` may still be
fetching mitmproxy — a shell opened before then won't have the proxy
override yet (check `~/scoped-token-shim/run.log` for progress). Use
`rc-claude` in that case: it waits for the shim to become reachable before
launching, and exits with a clear error if it never comes up.

## Applying the kit

This kit declares a `commands.startup` hook, which `sbx kit add`'s
recreate flow doesn't support yet (it refuses with a clear error). Pass it
at creation time instead:

```console
sbx create --kit /path/to/sbx-kits/claude-code-rc-shim/ claude .
```

## If the startup hook fails

The kit allows `pypi.org` and `files.pythonhosted.org` (for `uv tool install
mitmproxy`). If any request is blocked, check the log:

```console
sbx policy log <sandbox-name>
```

Then fix `spec.yaml` (or the caps) and recreate the sandbox:

```console
sbx rm <sandbox-name>
sbx create --kit /path/to/sbx-kits/claude-code-rc-shim/ claude .
```

## Configuration

The shim is configurable via environment variables — see the
[upstream README](https://github.com/cbrown1234/sbx-claude-code-rc-shim#configuration-env-vars)
for the full list. The most useful ones:

| var | default | meaning |
|---|---|---|
| `SHIM_DEBUG` | unset | `1` → log routing decisions to `shim.log` |
| `SHIM_STRIP_MSG_TIMESTAMP` | `1` | `0` → keep the server-injected "Message sent at …" reminder |
| `SHIM_LISTEN_PORT` | `8080` | port the shim listens on |

Since `run.sh` is now launched by the kit's `commands.startup` hook (already
running by the time you get a shell), exporting these in your own shell
comes too late to affect it. Add them to the `commands.startup` script in
this kit's `spec.yaml`, before `run.sh` starts.

## Iterating on the kit

```console
sbx kit validate ./claude-code-rc-shim/
sbx kit inspect ./claude-code-rc-shim/
```
