# Qiroex Agent Guide

This repository is a pure Elixir library. Keep changes minimal, behavioral, and verified.

## Scope

- Apply these rules to every code change in this repository.
- Do not consider a task complete if tests or Credo fail because of your changes.
- Prefer fixing root causes over suppressing warnings or loosening checks.

## Required Validation

Run these commands after changing code:

```sh
mix format
mix test
mix test --cover
mix credo --strict
```

## Formatting Standard

- Run `mix format` before finishing work on Elixir files.
- Keep source code aligned with the formatter instead of hand-preserving custom spacing or layout.
- If formatting changes reveal awkward code structure, simplify the code rather than fighting the formatter.

## Testing Expectations

- Add or update ExUnit tests for every behavior change or bug fix.
- When changing rendering, encoding, payload, or error-correction logic, cover the touched branches, not just the happy path.
- If a change is a refactor, run the full suite to prove behavior did not move.
- Prefer targeted tests while iterating, but always finish with the full commands above.

## Coverage Standard

- Treat coverage as a quality gate, not a vanity number.
- Keep coverage at least stable for touched areas.
- If `mix test --cover` shows uncovered new logic, add tests before finishing.
- Do not leave newly added public APIs or bug-fix paths without direct test coverage.

## Credo Standard

- `mix credo --strict` must pass before handing work back.
- Fix warnings by improving the code structure rather than disabling checks unless the user explicitly asks for a rule change.
- Avoid introducing high-arity helpers, deeply nested conditionals, or unclear naming that will trigger preventable issues.

## Change Discipline

- Preserve the library's existing public API unless the task requires a deliberate breaking change.
- Keep documentation and examples aligned when behavior changes.
- Do not modify generated output snapshots or assets unless they are directly affected by the task.
- If a command fails for unrelated pre-existing reasons, call that out explicitly and distinguish it from your changes.