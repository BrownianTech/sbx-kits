# gitlab-kit

A Docker Sandboxes mixin kit that adds GitLab support to any agent
(`claude`, `codex`, etc): installs `glab` and wires up token-based auth so
the agent can open merge requests, on top of the SSH agent forwarding
`sbx` already does automatically for git push/pull.

## How auth works

- **git clone/push** — handled entirely by `sbx` itself. If `SSH_AUTH_SOCK`
  is set on your host, Docker Sandboxes forwards your agent into the
  sandbox automatically. No config needed, and this kit doesn't touch it.
- **Opening an MR** — always an API call, which GitLab authenticates with a
  token, not SSH. This kit declares a `gitlab` credential (kit-spec v2:
  `credentials[].apiKey`) with an `inject` rule so the host-side proxy
  writes your token into the `PRIVATE-TOKEN` header on any request to
  gitlab.com. The token stays on your host; the sandbox only ever sees the
  literal placeholder string `proxy-managed` in `$GITLAB_TOKEN`.

Note the v2 credential schema has no env-var source field — the kit only
declares *what* it needs (`service: gitlab`, where to inject it); *where*
the real value lives is entirely up to the user-side bindings file
(`~/.config/sbx/credentials.yaml`), which the next step populates.

## Setup

1. Create a GitLab personal access token with `api` scope
   (User Settings → Access Tokens on gitlab.com or your instance).

2. Bind it to this kit's `gitlab` credential via the secrets store
   (keychain-backed on macOS/Linux with a working Secret Service, falling
   back to an encrypted on-disk store otherwise):

   ```console
   $ sbx secret set-custom -g \
       --host gitlab.com \
       --env GITLAB_TOKEN \
       --placeholder proxy-managed \
       --value glpat-xxxxxxxxxxxxxxxxxxxx
   ```

   Secrets are injected at sandbox **creation**, so run this before your
   first `sbx run`, not after.

3. Make sure your host has an SSH agent running with your GitLab key loaded:

   ```console
   $ eval "$(ssh-agent -s)"
   $ ssh-add ~/.ssh/id_ed25519
   $ ssh-add -l
   ```

## Use it

From inside a git repository:

```console
$ sbx run --clone claude --kit ./gitlab-kit/
```

`--clone` gives the agent its own clone inside the sandbox (your working
tree stays untouched, mounted read-only) and exposes the sandbox as a git
remote on your host. Drop `--clone` if you'd rather the agent edit your
working tree directly.

Inside the sandbox, once the agent has made changes:

```console
git push -u origin feature/my-change   # over SSH, forwarded agent
glab mr create --fill                  # over HTTPS, proxy-injected token
```

Back on your host, if you used `--clone`, pull the agent's work with:

```console
$ git fetch sandbox-<name>
```

## If the install command fails

The kit only allows `gitlab.com` through the sandbox's network policy. The
install command uses the GitLab Package Registry API (also on `gitlab.com`)
so no extra domains are needed. If something does get blocked, check the log:

```console
$ sbx policy log claude-blog
```

Add any blocked host you see there, then re-apply the kit:

```console
$ sbx kit add claude-blog ~/repos/sbx-kits/gitlab/
```

## Self-hosted GitLab

Replace every `gitlab.com` in `spec.yaml` with your instance's hostname
(three places: `caps.network.allow`, `credentials[].apiKey.inject[].domain`,
and the `glab config set -g host` install command) — and use the same
hostname in the `--host` flag when running `sbx secret set-custom`.

## Iterating on the kit

```console
$ sbx kit validate ./gitlab-kit/     # check the spec is well-formed
$ sbx kit inspect ./gitlab-kit/      # see what it resolves to
$ sbx kit add my-sandbox ./gitlab-kit/   # apply to an already-running sandbox
```
