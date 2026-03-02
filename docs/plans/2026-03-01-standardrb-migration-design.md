# StandardRB Migration Design

**Date:** 2026-03-01

## Context

The project uses RuboCop with a custom `.rubocop.yml` that disables or overrides ~12 cops. Several methods also carry inline `rubocop:disable Metrics/MethodLength` annotations. The goal is to replace this with StandardRB for consistency with other projects and to stop maintaining a custom linter config.

`standardrb --fix` has already been run and committed (315be50), so the codebase is already formatted to standard style.

## Decision

Switch from RuboCop to StandardRB (Option A — clean slate).

## Changes

1. **Gemfile** — replace `gem "rubocop"` with `gem "standard"`
2. **Config** — delete `.rubocop.yml`; add `.standard.yml` only if the verification pass reveals unresolvable offenses
3. **Inline annotations** — remove all 4 `rubocop:disable/enable` pairs for `Metrics/MethodLength` (standard does not enforce this cop)
4. **Pre-commit hook** — copy jojo's hook to `.git/hooks/pre-commit`; document install step in `CLAUDE.md`
5. **Verify** — run `bundle exec standardrb` to confirm clean pass

## Out of Scope

- No lint step added to Rakefile or CI; style enforcement happens at commit time via the pre-commit hook.
