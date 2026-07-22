# CLAUDE.md

Guidance for Claude Code (claude.ai/code) lives in **[AGENTS.md](AGENTS.md)**, the
single source of truth for this repo's architecture, invariants, and conventions.

This repo is a fork of google/or-tools carrying an Airspace Go-binding layer and a
binary release process; see [`AGENTS.md`](AGENTS.md) for what is airspace-specific
and what must survive upstream merges.

**This is a PUBLIC fork**: never commit references to internal Airspace services,
repos, or architecture, in any file, commit message, or PR. See "Invariants (never
violate)" in [`AGENTS.md`](AGENTS.md).

## Context Loading

**Before ANY change, load required context:**

Read the root [`AGENTS.md`](AGENTS.md). The upstream-merge conflict checklist, the
version plumbing rules, and the release/consumer coordination rules live there.

## Maintaining these docs

When a change makes a documented statement wrong, update [`AGENTS.md`](AGENTS.md) in
the same task. See the "Maintaining AGENTS.md files" section there for the full
rule.
