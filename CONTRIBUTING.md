# Contributing to sme-review

## Test runbook

### Deterministic tests (`tests/claude-code/`)

Bash + `claude -p` + grep. Run all:

```sh
cd sme-review/tests/claude-code
for t in test-*.sh; do
  echo "=== $t ==="
  ./$t
done
```

Each script plants a known-signal section, invokes the skill via `claude -p`, and asserts on grep-able output.

### Manual scenarios (`tests/scenarios/`)

Markdown files describing setup / invocation / expected behavior / anti-patterns. Run by hand. Not automated. The runbook in `tests/runbook.md` walks through each.

## Cap tuning (debug-log driven)

The soft cap of 4 is a baseline. To revisit:

1. Run real reviews with debug logging enabled (capture round-count and convergence-status per invocation).
2. If >20% of completed reviews hit the soft cap without converging, raise it incrementally to 5.
3. Repeat. The hard ceiling stays at 6 unless data strongly indicates otherwise.

No statistical tuning runs in v1. This is observation-driven, not pre-launch testing-driven.

## Adding a new persona

1. Create `experts/<slug>.md`. Use any existing persona (e.g., `experts/security.md`) as the canonical format reference. The 6 required H2 sections are:
   - `Identity & framing` (≤3 sentences; core mental model and one-sentence "lens"; no personality, biographical detail, or affect)
   - `What this domain typically misses in early designs` (5-8 concrete failure-mode bullets)
   - `Specialties — sub-domain lenses` (5-8 curated specialties, each with Lens + 3-5 "Especially watches for" bullets)
   - `Rubric — what to inspect, in order` (ordered list of inspection items)
   - `What rigorous reasoning looks like in this domain` (mapped to the 5 evidence shapes from `output-template.md`: file path with line range, executable check, calculation, threat scenario, external citation)
   - `Out of scope for this domain in design review` (explicit exclusions with adjacent-domain pointers like `(→ <other-domain>)`)
2. If the persona introduces a cross-cutting concern (TLS, rate limiting, idempotency, schema migrations, observability, auth boundaries), update the catalog table in `operations.md` → "Cross-cutting concerns catalog".
3. Add an entry to `experts/README.md`.
4. Update the curated-domain list in `operations.md` → "Specialty parsing & recognition" → "Curated catalog".

## Adding a specialty to an existing persona

1. Append a new `### <specialty-slug>` section to the persona's `## Specialties` block.
2. Lens (one sentence) + Especially watches for (3-5 bullets).
3. If the specialty introduces a cross-cutting concern, update the catalog table in `operations.md`.
