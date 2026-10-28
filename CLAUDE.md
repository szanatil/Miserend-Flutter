## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues (origin: szanatil/Miserend-Flutter), managed via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Specs

A spec lives in exactly one place: its `docs/spec/NNNN-*.md` file. Never copy a spec into an issue body or comment — this overrides any skill step (e.g. `to-spec`) that publishes the spec to the issue tracker. An issue for a spec names the spec by path and carries only what the spec does not.

`implement` takes only an issue that either holds its own specification in full (e.g. a bug report) or names the `docs/spec/` file to implement. Given any other issue, stop and say what is missing; don't infer a spec.

### Triage labels

Default five-role vocabulary (needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout — one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

### Coding standards

Writing or reviewing Dart code: follow `CODING_STANDARDS.md` (rule IDs like K2); formatting and lint are `dart format` and `flutter analyze`.

### Design rules

Writing, testing or reviewing UI code: follow `DESIGN.md` (rule IDs like SZ3, KO6). It is a standards source alongside `CODING_STANDARDS.md`. Matching is exact: any deviation from `DESIGN.md` — a similar but different value included — is a bug in a review. Tests of UI code follow its EH3–EH4 (both platforms, light and dark, 320/430 dp, text scale 2.0).
