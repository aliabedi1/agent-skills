# Code rules

Code and tests: comments, structure, error handling, dependencies, and the shape of generated changes.

## Ban list

**Symbols**
- `✅` in CLI or log output announcing success: state what actually happened instead.
- `🎉` in CLI or log output: same.

**Phrases**
- `All done!` / `Success!` standing in for the actual result of an operation.
- `debugger;` left in shipped code.
- `TODO: remove before merging` (delete the artifact itself, not just the note).

**Patterns**
- `except: pass` / `except Exception: pass`: never swallow an exception silently.
- `catch (e) {}`: same.

## Rules

### Reuse over duplication
Prevent: Before writing new logic, look for an existing function, module, or file that already does it and extend or import that, and when a change belongs in an existing file, edit that file rather than adding a parallel one.
Detect: Logic duplicated across files, or a new sibling file that reimplements most of an existing file's behavior for the sake of one addition, should be consolidated into the original with call sites updated, without changing behavior.

### Right-sized, honest changes
Prevent: Size a change to the task: touch only the files and lines the fix or feature actually requires, and get the implementation right on the first pass rather than landing something rough and expecting quick follow-up fixes.
Detect: A diff spanning many unrelated modules for a narrow task, or a history of the same code being fixed and re-fixed within days, signals a change that was too broad or too rushed; narrow it to what the task needs, or fold the follow-up fixes back into one correct change.

### Decompose into real, cohesive units
Prevent: Give each function and class one job; split a function handling many concerns into smaller ones, split a class accumulating branches and unrelated responsibilities, and only split across files when those files will actually stay independent of each other's internals.
Detect: A method that keeps growing to handle every case inline, a class with dozens of branches and mixed responsibilities, or files that look separate but reach into each other's private state all indicate missing decomposition; break the logic into focused units with real boundaries, preserving behavior.

### Match the existing architecture
Prevent: Before introducing a new way to do something the codebase already does elsewhere, such as a data-access path or a pattern for a cross-cutting concern, check how the rest of the codebase does it and follow that, unless the user explicitly asked for a different approach.
Detect: Code that bypasses an established pattern already used elsewhere for the same kind of concern is a maintainability problem even if it works; reroute it through the existing pattern.

### No speculative flexibility
Prevent: Build only what the current request needs: skip interfaces, factories, or strategy layers for a single implementation, skip config options or feature flags nobody asked for, and skip legacy parameter aliases or compat branches for callers that don't exist.
Detect: An abstraction layer with exactly one implementation, an unused settings knob, or a backwards-compat branch with no real caller is surface area kept for a hypothetical need; remove the layer and inline the one real behavior.

### Don't guard against states already ruled out
Prevent: Skip null checks, type checks, or emptiness checks when the call site, an earlier validation step, or the type system already guarantees that state can't occur; write the function for the states it can actually receive, not for states it can never see.
Detect: A guard clause that can never fire given how the function is actually called, such as a null check on a value just validated or emptiness handling for a list that can't be empty at that call site, is dead code that adds noise without adding safety; remove it and let the one place that actually owns validity or emptiness handle it.

### Don't swallow errors silently
Prevent: When you catch an exception, do something with it: log it with enough context to act on, handle the specific case, or let it propagate; never catch broadly just to suppress it.
Detect: A broad catch block with an empty or no-op body converts a bug into a silent failure; narrow the catch to the specific error and handle it, or log and re-raise.

### Comments carry only durable information
Prevent: Add a comment or docstring only when it tells the reader something the code doesn't already show, such as a non-obvious reason, a unit, or an invariant, and write it about what the code does and why, not about what you just changed.
Detect: A comment restating the next line, a docstring that only echoes the function's name and parameters back in prose, or a comment narrating the edit instead of the code all add reading effort without adding information and go stale the moment the code changes again; delete it, or replace it with the one thing about the code that actually needs explaining.

### No leftover debug or dead artifacts
Prevent: Before presenting a change as finished, remove anything that was only useful while writing it: debug prints, commented-out prior implementations, and TODOs addressed to yourself about cleanup still owed.
Detect: Print or log statements that only exist to inspect intermediate values, code commented out for a hypothetical future need, and self-addressed TODOs are leftovers from generation, not part of the solution; delete them.

### Say only what's demonstrated
Prevent: Report and document outcomes only to the extent the change actually establishes them: a completion message should reflect what actually happened, and a docstring or comment claiming a guarantee such as thread safety, full test coverage, or handling all edge cases should say so only if something in this change actually makes it true.
Detect: A generic success message unrelated to the actual result, or a claim of correctness or completeness with no corresponding mechanism or test in the change, is confidence the content hasn't earned; replace it with the concrete outcome, or drop the unbacked claim.

### Don't invent what isn't there
Prevent: Only call functions, import modules, and reference config keys that actually exist in this codebase, checking before using anything you're not certain is there, and verify a bug is still present before writing a fix for it.
Detect: A call into a function, module, or environment variable never defined anywhere in this codebase, or a fix for a bug an earlier change already resolved, means the content was generated from an assumption instead of the actual code; replace it with what the codebase actually provides, or drop the redundant fix.

### Extra scrutiny for security-critical code
Prevent: When a change touches auth, payments, secrets, or untrusted input, apply an explicit threat-model pass, thinking through what a malicious input or actor could do, rather than treating it like routine code, and never build raw untrusted input directly into HTML, queries, or shell commands.
Detect: Security-sensitive code reviewed the same as everything else, or untrusted data flowing into a sink like HTML rendering without escaping, needs that explicit scrutiny pass; fix the specific vulnerability using the escaping or parameterization mechanism the codebase already provides elsewhere.

### Test the spec, not the implementation
Prevent: Derive test cases and expected values from the intended contract, not from whatever the code currently returns, cover the edge cases the spec implies such as boundary values, invalid input, and error conditions, and assert the exact expected value rather than just that a call didn't crash or returned something.
Detect: A test whose expected value matches a bug in the implementation, a suite that only exercises the one obvious input, or an assertion that only checks a result is not-None, all indicate tests written from observing the code instead of the requirement; rewrite the assertion against the actual intended behavior and add the missing edge cases, and treat coverage generated in the same change as the code it tests as unverified until checked against the spec.

### Test real behavior, not just that a mock was called
Prevent: Mock only the collaborators that genuinely need isolating, such as external services or non-deterministic sources, and let pure functions and simple in-memory fakes run for real so the test can assert on an actual result.
Detect: A test where every collaborator is mocked and the only assertion left is that a mock was invoked proves nothing about what the code produced; replace the mocks with real calls or lightweight fakes and assert on the resulting value.

### Fix the bug, not the test
Prevent: When a test fails, fix the code it's testing; only change or remove the test itself if the test's own expectation was wrong.
Detect: A failing test skipped, commented out, or deleted in the same change that introduced the bug it was catching is the defect being hidden rather than fixed; restore the test and fix the underlying code instead.

### Older-model tells
Detect: A hardcoded placeholder value or a `TODO: implement this` sitting inside code presented as a finished solution is a stub dressed up as done; implement the missing behavior for real, or state plainly what's left to do instead of presenting it as complete.
