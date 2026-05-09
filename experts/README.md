# Experts catalog

Twelve curated personas + one freeform template. The orchestrator loads exactly one expert file per skill invocation based on the parsed `(domain, specialty)` (see `../operations.md` → "Specialty parsing & recognition").

## Curated personas (`<slug>.md`)

- `backend` — request paths, persistence, processing logic
- `api-design` — contracts, versioning, idempotency
- `frontend` — rendering, state, accessibility
- `prompting` — prompt-and-eval design
- `agent-systems` — loops, tool-use, memory, orchestration
- `security` — adversarial review, trust boundaries
- `data-modeling` — schemas, queries, indexing
- `infrastructure` — deploy, topology, networking
- `distributed-systems` — consistency, ordering, partitions
- `reliability` — SLOs, blast radius, graceful degradation
- `performance` — capacity, latency budgets, hot paths
- `testing` — testability, seams, observability hooks

## Freeform fallback

`_freeform-template.md` is used when:
- The user names a specialty whose domain isn't in the curated catalog (e.g., "SOC analyst review").
- The user names a specialty that doesn't match any curated persona's curated specialty list (the unified fallback path).

In both cases the orchestrator substitutes `{SPECIALTY}` with the user-supplied (sanitized) specialty string.

## Cross-cutting concerns policy

Some concerns appear under multiple specialties because they legitimately span them. The cross-cutting catalog is documented in `../operations.md` ("Cross-cutting concerns catalog"). Persona files duplicate the relevant bullets; cross-references between persona files are forbidden (per `anthropic-best-practices.md` lines 354-381).
