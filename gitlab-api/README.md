# gitlab-api kit

Installs `glab` and wires up token-based auth so the agent can open merge
requests on gitlab.com from inside a sandbox.

## How auth works

The host-side sbx proxy injects your GitLab token into the `PRIVATE-TOKEN`
header on every HTTPS request to `gitlab.com`. The sandbox only ever sees the
literal placeholder string `proxy-managed` in `$GITLAB_TOKEN` — your real
token never enters the sandbox.

## Setup

1. Create a GitLab personal access token with `api` scope
   (User Settings → Access Tokens on gitlab.com or your instance).

2. Bind it to this kit's `gitlab` credential:

   ```console
   sbx secret set-custom -g \
     --host gitlab.com \
     --env GITLAB_TOKEN \
     --placeholder proxy-managed \
     --value glpat-xxxxxxxxxxxxxxxxxxxx
   ```

   Secrets are injected at sandbox **creation**, so run this before your
   first `sbx run`, not after.

## Usage

```console
sbx kit add <sandbox-name> /path/to/sbx-kits/gitlab-api/
```

Or pass it at creation time:

```console
sbx run --kit /path/to/sbx-kits/gitlab-api/ claude
```

Inside the sandbox:

```console
glab mr create --fill
```

## Pairing with gitlab-ssh

This kit only opens port 443 to `gitlab.com`. If you also need `git push` /
`git pull` over SSH, apply the `gitlab-ssh` kit alongside this one:

```console
sbx kit add <sandbox-name> /path/to/sbx-kits/gitlab-api/
sbx kit add <sandbox-name> /path/to/sbx-kits/gitlab-ssh/
```

## Self-hosted GitLab

Replace every `gitlab.com` in `spec.yaml` with your instance's hostname
(three places: `caps.network.allow`, `credentials[].apiKey.inject[].domain`,
and the `glab config set -g host` command) — and use the same hostname in
the `--host` flag when running `sbx secret set-custom`.

## If the install command fails

All traffic stays on `gitlab.com` (the Package Registry API is also there).
If something is blocked, check the log and re-apply:

```console
sbx policy log <sandbox-name>
sbx kit add <sandbox-name> /path/to/sbx-kits/gitlab-api/
```

## Iterating on the kit

```console
sbx kit validate ./gitlab-api/
sbx kit inspect ./gitlab-api/
```
