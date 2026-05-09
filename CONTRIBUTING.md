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

1. Create `experts/<slug>.md` following the format in `docs/specs/2026-05-09-sme-review-design.md` Section 4 (Identity & framing → typically misses → Specialties → Rubric → reasoning → Out of scope).
2. Identity ≤ 3 sentences. No personality or biographical detail.
3. 5-8 curated specialty entries. Each with Lens + 3-5 "Especially watches for" bullets.
4. Out-of-scope items must be explicit; prevents drift into adjacent personas.
5. If the persona introduces a cross-cutting concern, update the catalog table in `operations.md`.
6. Add an entry to `experts/README.md`.
7. Update the curated-domain list in `operations.md` ("Specialty parsing & recognition" → "Curated catalog").

## Adding a specialty to an existing persona

1. Append a new `### <specialty-slug>` section to the persona's `## Specialties` block.
2. Lens (one sentence) + Especially watches for (3-5 bullets).
3. If the specialty introduces a cross-cutting concern, update the catalog table in `operations.md`.
