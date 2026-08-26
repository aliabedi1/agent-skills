# Naming rules

Names for variables, functions, classes, files, projects, products, and invented people or companies in examples.

These rules apply when the task calls for a name: you are declaring something in code, or you were asked to invent a person, company, or product. If the material you were given leaves something unnamed, leave it unnamed. Supplying a name nobody asked for is invention, not naming.

## Ban list

**Words that are semantically empty**
- `data`, `item`, `thing`, `value`, `result`, `info`, `temp`, `obj`, `foo`, `bar`: name it for what it actually holds.

**Words that claim more authority than a class has**
- `Manager`, `Orchestrator`, `Engine`, `Processor`, `Universal`, `Smart`, `Intelligent`: name the class for the specific responsibility it holds.

**Words that mark a revision instead of describing content**
- `Final`, `Enhanced`, `Updated`, `Complete`, `New`, `V2`: describe what changed, or let version control carry the history.

**Words for a dumping-ground module**
- `utils`, `helpers`, `common`, `misc`: split into files named for what their contents actually do together.

**Names from the small AI-favorite pool for invented people, companies, and products**
- `Elara`, `Elena`, `Clara`, `Nova`, `Luna`, `Aria`, `Lyra`, `Isabella`, `Mara`, `Voss`, `Vance`, `Acme Corp`, `TechCorp`, `Globex`, `Initech`, `Contoso`, `Nexus`, `Orion`, `Atlas`, `Zenith`, `Apex`, `Aether`: pick a name outside this cluster.

## Rules

### Name it for what it is
Prevent: When a name is hard to choose because the thing it names actually bundles several unrelated concerns, split the design rather than inventing a vague catch-all label for the bundle; apply the same test to a module whose name is turning into a bucket for whatever doesn't obviously belong elsewhere.
Detect: Find a parameter, object, or module that has absorbed multiple unrelated things under one vague name, and split it, at the call site or into separate files named for what the pieces actually are, without changing behavior.

### Match the name to the behavior
Prevent: Only claim in a name what the implementation actually verifies or guarantees; when writing behavior you haven't fully checked, name it after the mechanism rather than a stronger result.
Detect: Check whether a name's plain meaning matches what the code actually computes or returns, and rename it to the accurate term wherever the two have drifted apart.

### Keep naming consistent across the codebase
Prevent: Once a verb for an operation, or a singular versus plural form for a value, is established anywhere in the codebase, reuse it everywhere that operation or kind of value appears instead of picking a fresh synonym per file.
Detect: Find the same operation named with different verbs in different files, a verb that undersells what a function actually does, or a singular name holding a collection, and standardize each on whichever form is already established elsewhere.

### Prefix booleans
Prevent: Give boolean variables and parameters an is, has, or can prefix so a reader can tell them apart from the data they gate, especially where the language has no static type to signal it.
Detect: Find booleans named as bare nouns or adjectives and add the is, has, or can prefix, unless the surrounding code is statically typed and consistently omits it already.

### Follow the existing case convention
Prevent: Match whatever casing convention the surrounding file or codebase already uses for identifiers, rather than defaulting to one convention regardless of context.
Detect: Find a name whose casing breaks from the convention used throughout the rest of the file, and rename it to match.

### Reach for the one precise term
Prevent: Look for the single existing word a domain expert would use for a concept instead of stacking several generic words together to describe it, but stop once the name is clear rather than trimming past recognizability.
Detect: Find names built by stacking generic dictionary words that restate every attribute of a thing, and replace them with the shorter precise term that already exists for the same concept.

### Don't bake revision markers into a name
Prevent: Name a function, variable, or file for what it currently does or contains, and let version control or a changelog carry the history, instead of a suffix or adjective marking that it was revised or is the current count.
Detect: Find a name or filename carrying a status word or a bare count that distinguishes two versions of the same thing, and rename it for the current content, or for the real difference between the two things.

### Match a class's name to its actual role
Prevent: Name a class or module for the specific responsibility it holds, not for how important or general it sounds.
Detect: Find class or module names built from grandiose nouns or intensifying prefixes that assert authority the implementation doesn't back up, and rename them to the specific responsibility the code holds.

### Avoid the AI-favorite name pool
Prevent: When inventing a person, company, or product name for an example, pick something outside the small, recurring cluster models default to, and vary the choice across examples instead of reusing a signature name.
Detect: Find invented character, company, or product names drawn from that same small recurring pool, and replace each with a name outside it, keeping its role in the example unchanged.

### Name a file for its subject, not the session that produced it
Prevent: Name a new document or file for what it's about, specific enough that someone who wasn't part of the conversation that produced it can tell what it's for, rather than labeling it after the act of writing it up.
Detect: Find repo-root markdown files named as generic session artifacts, a summary, a note, a report, a plan, with no topic in the name itself, and rename each for the actual subject it documents.

### Older-model tells
Detect: In legacy code a model is asked to extend, watch for ambiguous abbreviations that could stand for several different words, and for bare symbolic operators borrowed from functional programming; expand each abbreviation to the intended full word and replace a symbolic operator with a named function, without changing behavior. This is rare in fresh output from current models, so it matters mainly when de-slopping older content.
