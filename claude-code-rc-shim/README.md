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

## What this kit does

The install command clones the shim repo to `~/scoped-token-shim` and runs
`setup.sh`, which:

1. Installs `mitmproxy` (isolated, via `uv tool install --python 3.12`)
2. Generates mitmproxy's CA cert (brief headless run)
3. Appends the CA to `/etc/ssl/certs/ca-certificates.crt` so node, python,
   and curl all trust the shim's TLS interception

No credentials are declared — the shim works entirely at the network layer.

## Usage

After the kit is applied, inside the sandbox:

```console
# 1. Start the shim (keep this running in a separate terminal or background)
~/scoped-token-shim/run.sh &

# 2. Launch Claude Code routed through the shim
~/scoped-token-shim/rc-claude.sh

# 3. Inside Claude Code, start a remote-control session
/remote-control
```

`rc-claude.sh` checks that the shim is reachable before launching and sets
both upper- and lower-case proxy env vars (node/undici prefers the lowercase
names which sbx pre-sets to the gateway; without overriding both, the shim
is bypassed silently).

## Applying the kit

```console
# Apply to an already-running sandbox
sbx kit add <sandbox-name> /path/to/sbx-kits/claude-code-rc-shim/

# Or pass it at creation time
sbx run --kit /path/to/sbx-kits/claude-code-rc-shim/ claude
```

## If the install command fails

The kit allows `github.com`, `objects.githubusercontent.com`, `pypi.org`, and
`files.pythonhosted.org`. If any request is blocked, check the log:

```console
sbx policy log <sandbox-name>
```

Then re-apply the kit after adding any missing domain:

```console
sbx kit add <sandbox-name> /path/to/sbx-kits/claude-code-rc-shim/
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

## Iterating on the kit

```console
sbx kit validate ./claude-code-rc-shim/
sbx kit inspect ./claude-code-rc-shim/
```
