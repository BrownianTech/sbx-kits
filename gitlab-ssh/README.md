# gitlab-ssh kit

Opens port 22 to `gitlab.com` and forwards your host's SSH agent so git
operations over SSH work inside a sandbox.

## How it works

Under v3 kits, a sandbox gets no SSH agent unless a kit asks for one. This
kit declares `ssh-agent@1`, so sbx forwards your host's agent and sets
`SSH_AUTH_SOCK` inside the sandbox. Your private keys stay on the host. The
grant only covers logins as `git@gitlab.com`, so the agent can't log in to
other servers or sign commits. The kit also adds the `gitlab.com:22` allow
rule that the default-deny network policy would otherwise block.

The agent request is optional: with no agent on the host the sandbox still
starts, but SSH operations will fail.

## Prerequisites

Make sure your host has an SSH agent running with your GitLab key loaded:

```console
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
ssh-add -l
```

## Usage

```console
sbx kit add <sandbox-name> /path/to/sbx-kits/gitlab-ssh/
```

Or pass it at creation time:

```console
sbx run --kit /path/to/sbx-kits/gitlab-ssh/ claude
```

Then inside the sandbox:

```console
git push -u origin feature/my-change
```

## Pairing with gitlab-api

If you also need to open merge requests (via `glab`), apply the
`gitlab-api` kit alongside this one — it adds token auth and the `glab`
CLI without duplicating the SSH cap.
