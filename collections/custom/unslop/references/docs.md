# Docs and README rules

Overlay for READMEs, docs, and long-form technical writing. The writing base rules apply throughout; this file holds only the deltas specific to documentation.

## Ban list

- `SUMMARY.md`, `IMPLEMENTATION_NOTES.md`, `CHANGES_MADE.md`, and similar session-log filenames: process artifacts nobody asked for, don't create them unless the user requested a written summary of the work

## Rules

### Add structure only when the doc earns it
Prevent: Add a badge row, a table of contents, or admonition callouts only when the doc's length or genuine complexity calls for them, not as default README furniture, and reserve a callout for the one or two things a reader truly needs flagged.
Detect: Find badge rows carrying no real signal, a table of contents on a doc short enough to scan directly, and callouts wrapping routine steps, and strip or collapse each back to what the doc's actual size and content need.

### Don't manufacture proof, plans, or comparisons
Prevent: Give a project stats, roadmap items, or a competitor comparison only when they're real, requested, and sourced; don't add any of them as decoration to make the project look more traction-backed, planned, or superior than it is.
Detect: Find unverified round numbers used as social proof, generic evenly-spaced roadmap checkboxes with no tracking link or date, and unsolicited us-versus-them tables sourced from nowhere, and cut each or replace it with the real, checkable fact.

### Write this project's specifics, not generic boilerplate
Prevent: Write prerequisites, contributing steps, license notes, and feature descriptions in terms of what's actually true and actionable here, the real version constraints, the actual setup and test commands, the specific mechanism behind a claimed quality, rather than language that could describe any project.
Detect: Find prerequisite lists, contributing or license sections, and feature bullets that could belong to any repo, environment truisms, fork-branch-PR boilerplate, adjectives with no mechanism behind them, and replace each with this project's actual commands, constraints, or behavior.

### Match content to the doc's actual job
Prevent: Write a tutorial as steps toward a first success, a how-to as steps for a task the reader already knows they want, reference as a dry lookup ordered to match the system's real structure, and explanation as background, and keep each in its lane instead of pulling in what belongs to one of the others.
Detect: Find tutorials interrupted by unrequested background, how-to guides that open with conceptual explanation instead of the steps, and reference entries that wander into design rationale or are ordered by novelty instead of the system's structure, and move the displaced material to its own explanation doc or cut it.

### One definition per concept, linked not re-explained
Prevent: Define a shared concept once, in the doc whose job that is, and have every other page reference it rather than re-explaining it from scratch.
Detect: Find near-duplicate explanations of the same concept scattered across multiple pages with slightly different wording, and consolidate them into a single canonical definition that the other pages link to.

### Verify before you document, and add what the signature can't show
Prevent: State a command, flag, or API detail only when you can verify it against the real product, and in a reference entry or feature description, add the behavior a reader can't already see, the failure mode, edge case, unit, or caveat, rather than stopping at the happy path or restating the name in prose.
Detect: Find confident-sounding commands, flags, or API claims that don't check out against the real product, reference entries that just translate the signature into a sentence, and feature descriptions that stop at the surface, and fix each by removing the unverifiable claim or adding the missing behavioral detail.
