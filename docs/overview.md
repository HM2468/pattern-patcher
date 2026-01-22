# **PatternPatcher**

**PatternPatcher** is a tool for applying **large-scale, AI- or rule-generated code changes** in a way that is **safe, reviewable, and production-ready**.

Instead of performing risky one-click rewrites, PatternPatcher enforces **human review, character-level precision, and file-scoped Git commits**, making every change **auditable, reversible, and worth committing**.

It is designed for real-world engineering constraints:

- Readable Git history

- Incremental rollout

- Explicit human approval

- Deterministic application

- Safe failure and conflict handling


* * *

## **Why PatternPatcher Exists**

Large legacy codebases frequently require changes such as:

- Systematic replacement of text, APIs, comments, or i18n keys

- Gradual migration from old patterns to new standards

- AI- or rule-generated suggestions that **cannot be auto-committed**

- Mandatory human review and conflict detection

- Strict control over Git commit granularity


### **Limitations of Existing Approaches**

| **Approach** | **Core Problems** |
| --- | --- |
| Scripts / regex | Invisible changes, no review, no rollback |
| IDE batch replace | No intent tracking, no collaboration, unsafe |
| One-shot AI rewrites | Non-deterministic, unreviewable, extremely risky |
| Diff-based patching | Fragile under concurrent edits |

From an engineering perspective, the hard part is **not generating changes**, but ensuring that:

> Every change is understandable, verifiable, traceable, and safe to commit.

PatternPatcher is built around this conclusion.

* * *

## **Positioning in the AI Era**

AI tools (Cursor, MCP, Copilot, etc.) excel at:

- Small local edits

- Interactive refactors

- Context-aware code generation


However, at large scale they face fundamental limits:

- **Reliability**: context truncation and model uncertainty

- **Timeliness**: multi-round inference becomes uncontrollable

- **Cost**: whole-repo changes are economically expensive

- **Reviewability**: AI outputs results, not reviewable change units


PatternPatcher does not replace AI.

Instead, it answers a different question:

> *How can AI- or rule-generated changes be reviewed, trusted, and safely committed at scale?*

* * *

## **Core Design Principles**

1.  **Human review is mandatory**

    Auto-generation ≠ production-ready code

2.  **Change intent must be explicit**

    Every modification is a deliberate, reviewable unit

3.  **Precision over guessing**

    Changes apply only when the original code matches exactly

4.  **Git history is a first-class concern**

    Commits must remain readable and meaningful

5.  **Failures must be safe and recoverable**

    No silent overwrites, no partial corruption


* * *

## **Key Features**

- 🔍 **Pattern-based repository scanning**

    Identify exact occurrences using configurable language- and regex-based rules.

- 👀 **Human-in-the-loop review workflow**

    Every change is approved or rejected individually.

- 🎯 **Character-level application precision**

    Changes apply only if the original text matches exactly.

- 📁 **File-scoped Git commits**

    Each file is committed independently, preserving clean Git history.

- 🔁 **Conflict-aware and reversible execution**

    Conflicts and failures are detected explicitly and handled safely.


* * *

## **Core Concepts**

### **1\. Pattern-Based Scanning (Scan)**

The repository is scanned using configured patterns.

Each match records:

- File path

- Line number (line_at)

- Character range (line_char_start, line_char_end)

- Original matched text (matched_text)


```
RepositoryFile
  └── Occurrence
        - line_at
        - line_char_start
        - line_char_end
        - matched_text
```

These coordinates become the **only trusted reference** for applying changes.

* * *

### **2\. OccurrenceReview: The Smallest Reviewable Unit**

Each Occurrence generates an OccurrenceReview, representing **one minimal code change**.

An OccurrenceReview contains:

- Original context

- Rendered replacement code

- Review status:

    - pending

    - approved

    - rejected

- Apply status:

    - not_applied

    - applied

    - conflict

    - failed


> One OccurrenceReview = one independently reviewable and decidable change.

* * *

### **3\. Character-Level Patch Application**

PatternPatcher does not apply diffs blindly.

Instead, it validates changes using exact coordinates:

```
lines[line_at - 1][start...end] == matched_text
```

- ✅ Exact match → apply allowed

- ❌ Mismatch → conflict detected


This guarantees:

- External edits are detected automatically

- No silent overwrites

- Fully deterministic behavior


* * *

### **4\. Git-Controlled Apply Process**

The apply flow is strictly layered:

1.  Modify only the working tree

2.  Stage only the target file:


```
git add -- <file>
```

3.  Commit only when **all reviews for that file are approved**:

```
git commit -m "..." -- <file>
```

✔ Each file is committed exactly once

✔ Approval order does not matter

✔ Other staged files are never affected

* * *

## **Failure and Conflict Handling**

### **Conflict Detection**

If file content no longer matches the scan record:

- No write occurs

- apply_status = conflict

- Full error context is returned


### **Write Failure**

- I/O or permission errors

- Partial changes are rolled back

- apply_status = failed


### **Git Operation Failure**

- Errors from git add or git commit

- Error output is preserved

- Already-applied files remain unaffected


* * *

## **Overall Architecture**

```
Repository
  ├── RepositoryFile
  │     └── Occurrence
  │            └── OccurrenceReview
  │
  ├── ScanRun / Snapshot
  │
  └── GitCli
         ├── git add <file>
         ├── git commit -- <file>
         ├── git diff --cached
         └── git cat-file / ls-tree
```

Key service:

- ApproveOccurrenceReviewService

    - Validation

    - Patch application

    - Conflict detection

    - Git staging & commit

    - Safe error handling


* * *

## **Typical Use Cases**

- Large-scale i18n or copy migrations

- Gradual API / SDK upgrades

- Legacy code normalization

- AI-generated refactors requiring human approval

- Safe batch modifications in collaborative teams


* * *

## **Non-Goals**

PatternPatcher intentionally does **not** aim to:

- ❌ Perform unreviewed one-click rewrites

- ❌ Replace CI, linting, or code review

- ❌ Automatically “fix everything”


* * *

## **Current Status**

- ✅ Core workflow fully implemented

- ✅ Validated in large real-world repositories

- 🚧 Possible future extensions:

    - Dry-run mode

    - Batch approval

    - Enhanced review UI

    - Pluggable AI generators


* * *

## **Summary**

PatternPatcher optimizes for **trust, not speed**.

It ensures that even at massive scale, every code change remains:

- Understandable

- Reviewable

- Traceable

- Worth committing


* * *

## **License**

PatternPatcher is licensed under **AGPL-3.0**.

Commercial use (including internal enterprise use or SaaS)

requires either AGPL compliance or a separate commercial license.

📧 Contact: **huangmiao2468@gmail.com**