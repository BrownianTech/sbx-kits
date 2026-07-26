#!/usr/bin/env bash
#
# Reproduces: sbx kit add silently ignores caps.network.allow rules.
#
# Expected: after `sbx kit add`, the kit's network allow rule should appear
#           in `sbx policy ls`.
# Actual:   the rule is absent; only files, init files, and startup commands
#           are applied (per the `sbx kit add` docs).
#
# For comparison, Case 2 applies the same kit via `--kit` at creation time,
# where the rule is expected to be present.
#
# Usage: ./repro.sh
# Requirements: sbx on PATH, Docker running.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SANDBOX_ADD="kit-policy-repro-add"
SANDBOX_CREATE="kit-policy-repro-create"
RULE="repro.example.com:9999"

# ─── Helpers ─────────────────────────────────────────────────────────────────

destroy() {
  sbx stop "$1" 2>/dev/null || true
  sbx rm -f "$1" 2>/dev/null || true
}

rule_status() {
  local out
  out=$(sbx policy ls "$1" 2>/dev/null)
  if echo "$out" | grep -q "$RULE"; then
    echo "PRESENT"
  else
    echo "ABSENT"
  fi
}

# ─── Case 1: sbx kit add to a running sandbox ────────────────────────────────

echo "── Case 1: apply kit via 'sbx kit add' ─────────────────────────────────"
destroy "$SANDBOX_ADD"
sbx create --name "$SANDBOX_ADD" shell /tmp
echo "  rule before kit add : $(rule_status "$SANDBOX_ADD")"
sbx kit add "$SANDBOX_ADD" "$SCRIPT_DIR" >/dev/null
echo "  rule after  kit add : $(rule_status "$SANDBOX_ADD")"
echo "  expected: PRESENT   actual: $(rule_status "$SANDBOX_ADD")"
destroy "$SANDBOX_ADD"

# ─── Case 2: --kit at creation (comparison) ──────────────────────────────────

echo
echo "── Case 2: apply kit via '--kit' at creation (comparison) ──────────────"
destroy "$SANDBOX_CREATE"
sbx create --name "$SANDBOX_CREATE" --kit "$SCRIPT_DIR" shell /tmp
echo "  rule after creation : $(rule_status "$SANDBOX_CREATE")"
echo "  expected: PRESENT   actual: $(rule_status "$SANDBOX_CREATE")"
destroy "$SANDBOX_CREATE"
