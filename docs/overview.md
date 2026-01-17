# PatternPatcher

PatternPatcher helps teams apply **AI- or rule-generated code changes at scale with confidence**.

It combines **precise pattern scanning**, **human-in-the-loop review**, and **file-scoped Git commits** to make large refactors **safe, auditable, and production-ready**.

Rather than performing risky one-click rewrites, PatternPatcher is designed to respect real-world engineering constraints:
- Git history readability
- Incremental rollouts
- Explicit human approval
- Deterministic and reversible changes

---

## Key Features

- 🔍 **Pattern-based scanning**
  Identify exact code occurrences across large repositories using configurable patterns.

- 👀 **Human review workflow**
  Every change is reviewed and approved (or rejected) individually before being applied.

- 🎯 **Character-level precision**
  Patches are applied only when the original code matches exactly—no silent overwrites.

- 📁 **File-scoped Git commits**
  Each file is committed independently, preserving clean and readable Git history.

- 🔁 **Conflict-aware and reversible**
  Conflicts and failures are explicitly detected and safely handled.

---

## Typical Use Cases

- Large-scale i18n or copy migrations
- Gradual API / SDK upgrades
- Legacy code style normalization
- AI-assisted refactoring with mandatory human confirmation
- Safe batch modifications in collaborative teams

---

## Tech Stack

PatternPatcher is built on a modern, production-ready Ruby ecosystem:

| Component  | Version |
|-----------|---------|
| **Ruby**  | ≥ 3.4 |
| **Ruby on Rails** | ≥ 8.0 |
| **PostgreSQL** | ≥ 14.20 |
| **Git** | ≥ 2.50 |
| **Redis** | ≥ 8.4.0 |
| **Sidekiq** | Latest stable |

---

## Design Philosophy

PatternPatcher is built on a simple but strict principle:

> Large-scale code changes must remain **understandable, verifiable, and worth committing**.

It does not aim to replace AI tools.
Instead, it **bridges AI generation with engineering-grade control**, ensuring that every change can be reviewed, trusted, and safely merged.

---

## License

PatternPatcher is licensed under **AGPL-3.0**.

For commercial use or alternative licensing, please contact the author.