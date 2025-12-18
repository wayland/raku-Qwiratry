<!--
Sync Impact Report
Version: unversioned -> 1.0.0
Modified principles: Initial publication (no renames)
Added sections: Core Principles; Quality and Safety Standards; Workflow and Review Gates; Governance
Removed sections: none
Templates updated: ✅ /.kittify/missions/software-dev/templates/plan-template.md; ✅ /.kittify/missions/software-dev/templates/spec-template.md; ✅ /.kittify/missions/software-dev/templates/tasks-template.md
Follow-up TODOs: none
-->

# Qwiratry Constitution

## Core Principles

### P1. Test-First, Evidence-Backed Delivery
- Write failing automated tests before implementation; no change merges without matching tests.
- Every behavior change carries unit coverage and, when crossing boundaries, integration/contract tests.
- CI is a gate; flakiness is treated as a defect and must be resolved before sign-off.

### P2. Explicit Data Contracts and Safe Mutation
- Model data with documented schemas; validate inputs/outputs at boundaries.
- Prefer immutable flows; where mutation is required, isolate it and log it.
- Backward-compatibility for data formats is maintained or migration plans are approved before release.

### P3. CLI-First with Observable Text I/O
- Expose feature capabilities via CLI entry points that accept args/stdin and emit stdout/stderr.
- Default output supports both human-readable text and structured formats (JSON) for tooling.
- Emit structured logs and metrics for every externally visible action; no silent failures.

### P4. Security and Privacy by Default
- Enforce least-privilege access, secrets isolation, and dependency health checks before shipping.
- Handle personal or sensitive data only with explicit justification, minimization, and auditability.
- Security reviews and threat considerations accompany changes that touch auth, data access, or networking.

### P5. Simplicity, Small Increments, and Operability
- Ship in small, reversible slices; avoid speculative abstractions.
- Prefer straightforward designs that ease debugging and onboarding.
- Operational readiness (runbooks, metrics, alerts where applicable) is part of “done”.

### P6. Raku Coding Style

- Where possible, we code like a mix of Tim Nelson (Wayland Smith) and Elizabeth Mattijsen (lizmat).  
- Each class is documented with its own Rakudoc embedded in it

## Quality and Safety Standards

- Performance expectations are stated per feature; plans must record targets and test approaches.
- Documentation: update user-facing and operator notes alongside changes; keep CLI usage examples current.
- Observability: record what is needed to debug in production (logs, metrics, traces) with sampling defined.
- Error handling: fail fast with actionable messages; avoid swallowing errors.
- Releases: require green automated checks, reproducible build steps, and rollback/mitigation notes.

## Workflow and Review Gates

- Discovery/plan/spec/tasks must cite how they satisfy each core principle; unresolved gaps block progression.
- Before implementation, establish Constitution Check items: tests to add first, data contracts to validate, CLI/UX surface, security/privacy considerations, and observability hooks.
- Code review is mandatory; reviewers verify principle adherence, not just correctness.
- Exceptions to principles require explicit, documented rationale plus compensating controls.

## Governance

- This constitution supersedes other conventions; deviations require written approval and a dated rationale.
- Amendments follow semantic versioning: MAJOR for incompatible changes, MINOR for new/expanded principles, PATCH for clarifications.
- Ratification/amendment history is maintained in this file; each change updates Last Amended.
- Compliance reviews occur at spec, plan, tasks, and implementation review stages; violations must be resolved or formally waived.
- Store references to supporting guidance and scripts in commands/templates to keep them synchronized.

**Version**: 1.0.1 | **Ratified**: 2025-12-16 | **Last Amended**: 2025-12-16
