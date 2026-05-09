# sme-review

A Claude Code skill that performs a rigorous domain-expert review of a design section currently in conversation. Internal expert-vs-reviewer debate produces validated findings + a revised section.

## Install

From this catalog directory:

- `./install.sh` — copy mode (default, recommended). Static copy. iCloud-safe.
- `./install.sh symlink` — symlink mode. Catalog edits take effect immediately. For active development.
- `./install.sh --force` — overwrite an existing install.

Verify installation: `ls -la ~/.claude/skills/sme-review`.

## Usage

After a design section is presented in conversation, invoke naturally:

- "Get a backend expert review of this."
- "Do a network security SME review."
- "Get a Postgres-perf backend expert on this section."
- "Review this for distributed-systems concerns."

The skill auto-triggers when your prompt asks for a domain-expert critique of pre-implementation design content.

## Scope (v1)

- **One section per invocation.** For multi-section reviews, invoke once per section.
- **Single-user concurrency.** Concurrent invocations on the same `(section, domain, specialty)` are rejected via lockfile (not merged).
- **Pre-implementation design only.** For code review of committed work, use `requesting-code-review`.
- **Soft cap of 4 rounds, hard ceiling of 6.** Beyond the ceiling, unresolved findings surface as "disputed" for user adjudication.

## Uninstall

```sh
rm -rf ~/.claude/skills/sme-review
```
