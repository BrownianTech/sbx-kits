# syntax=docker/dockerfile:1
# glab as an overlay: a version- and SHA256-pinned release binary baked into
# the kit image at build, instead of downloaded by an install hook at every
# sandbox create.
#
# GLAB_VERSION comes from the descriptor's `version` arg (buildArg). The
# per-arch digests below are pinned to that release, so overriding the
# version without updating them fails the build. Bumping glab means editing
# the arg default in the .yaml and both digests here, with values from the
# release's checksums.txt:
#   https://gitlab.com/gitlab-org/cli/-/releases/v<version>/downloads/checksums.txt
FROM alpine:3.22 AS build
ARG GLAB_VERSION
ARG TARGETARCH
RUN set -eu; \
    [ -n "${GLAB_VERSION}" ] || { echo "GLAB_VERSION must be set" >&2; exit 1; }; \
    case "${TARGETARCH}" in \
      amd64) sha256=580dbca43835b47267e512476a442f6b2e8785a82b26ccacee22bd7010662b2d ;; \
      arm64) sha256=7c4befd271203745b674caae2a69590ea5f9c6e5dee78bd3b40ba0e2a7c74749 ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    tarball="glab_${GLAB_VERSION}_linux_${TARGETARCH}.tar.gz"; \
    wget -q -O /tmp/glab.tgz \
      "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/${tarball}"; \
    echo "${sha256}  /tmp/glab.tgz" | sha256sum -c -; \
    tar -C /tmp -xzf /tmp/glab.tgz bin/glab; \
    mkdir -p /out/usr/local/bin; \
    install -m 0755 -o 0 -g 0 /tmp/bin/glab /out/usr/local/bin/glab

# The binary must report exactly the version the descriptor provides.
RUN set -eu; \
    reported="$(/out/usr/local/bin/glab --version | head -n1)"; \
    echo "glab --version: ${reported}"; \
    printf '%s\n' "$reported" | tr -s ' ,():\t' '\n' | grep -Fxq "${GLAB_VERSION}" || { \
      echo "pin mismatch: descriptor says ${GLAB_VERSION}, binary reports '${reported}'" >&2; exit 1; }

# Lands in /usr/local/bin on any base; nothing under /home/agent, which may
# be a mounted volume.
FROM scratch
COPY --from=build /out /
