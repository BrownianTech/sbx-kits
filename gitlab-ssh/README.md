# gitlab-ssh kit

Opens port 22 to `gitlab.com` so git operations over SSH work inside a
sandbox.

## How it works

sbx automatically forwards `SSH_AUTH_SOCK` from the host into the sandbox,
so your existing SSH key is available without any extra setup. The only
thing blocking `git push` / `git pull` over SSH is the default-deny network
policy — this kit adds the single allow rule needed.

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
