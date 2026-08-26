# Writing base rules

General prose rules shared by every surface where Claude produces text: docs, UI copy, and anything else that's mostly words. The docs/README and UI copy overlays assume these rules apply and add only their own medium-specific deltas on top.

## Ban list

**Words**
- `tapestry`, `camaraderie`, `palpable`, `testament`, `interplay`, `landscape`, `weave`/`woven`: worn metaphor vocabulary, name the specific thing instead
- `delve`/`delving`, `underscore`, `showcase`, `foster`, `garner`, `highlight`, `enhance`: reach for a plainer verb
- `utilize`, `phenomenon`, `cul de sac`, `status quo`: Latinate inflation, use "use," "thing," "dead end," "current state"
- `boasts` (meaning "has"): use "has"
- `nestled`, `vibrant`, `breathtaking`: travel-brochure language for a subject nobody is selling

**Phrases**
- `serves as`, `functions as`: use "is"/"are"
- `stands as a testament to`, `marks a pivotal moment`, `leaves an indelible mark`, `rich cultural heritage`: significance inflation
- `in order to` (to), `due to the fact that` (because), `at this point in time` (now), `has the ability to` (can), `in the context of`/`with respect to`/`in terms of`: padding with a shorter plain equivalent available
- `let's dive in`, `here's what you need to know`, `i hope this helps`, `let me know if you have any other questions`, `great question`, `you're absolutely right`, `honestly?`, `here's the thing`: conversational wrapper, cut rather than rephrase

**Symbols**
- `—`, `–` used as parenthetical punctuation: replace with commas, parentheses, or a period; the tell is the rate across a piece, not one instance
- `“ ” ‘ ’`: replace with straight `" '` unless the target format itself uses typographic quotes
- decorative emoji in headings or list items (🚀, ✨, ✅, and similar): remove unless the emoji is the actual content

**Leaked tool markup**
- `contentReference`, `oaicite`, `[cite:`, `grok_card`, `ppl-ai-file-upload`, lenticular brackets `【` `】`: strip, these are chat-tool citation internals, not real citations

## Rules

### Plain word over dressed-up word
Prevent: Reach for the plainest accurate word for the register you're in. Let a real "is" or "are" stand instead of dressing the verb up as something more considered, and skip elevated near-synonyms and foreign-derived vocabulary when the plain native word says the same thing.
Detect: Look for clusters of over-formal verbs, worn metaphors, Latinate vocabulary, and copula-avoidance substitutes rather than judging any single instance alone, and swap in the plain word or verb a careful human writer would actually use.

### No inflated significance or sales pitch
Prevent: State what a subject actually is, or what actually happened, at the scale it actually happened. Don't dress an ordinary fact up as a turning point or a legacy, and don't apply travel-brochure language to something nobody is selling.
Detect: Find generic significance-inflation phrasing and tourism-brochure adjectives attached to subjects with no promotional context, and replace them with the specific, checkable fact underneath.

### Repeat the clear term
Prevent: Repeat the same noun or term across a passage when that's what's actually clearest, instead of cycling through near-synonyms purely for variety.
Detect: Find chains of near-synonyms standing in for one repeated term and consolidate them back to whichever term is clearest, unless the passage genuinely needs the variety.

### Plain shape for lists and contrasts
Prevent: Give a list or a contrast the shape it actually has, a plain conjunction, the real number of items, or a two-item comparison, rather than forcing a not-only-but-also reveal, a manufactured "rather than," a rule-of-three triplet, or an X-to-Y range onto content that isn't structured that way.
Detect: Find these templates applied to facts that don't need the extra rhetorical weight (a surprise-framed "not only," a manufactured contrast, an adjective list padded to exactly three, a range implying a continuum that isn't there) and flatten each to the plain list or comparison the content supports.

### Concrete subjects and verbs
Prevent: Keep the grammatical subject and verb concrete: say who did what, rather than converting the action into an abstract noun, propping a "that"-clause up as the subject, or stapling on a participial clause to imply analysis that isn't there.
Detect: Find nominalizations, "that"-clause subjects, and tacked-on participial phrases added for apparent weight, and rewrite with a real subject and an active verb doing the work instead.

### Cut the padding
Prevent: Say things in as few words as the meaning needs. Don't reach for a wordy formula when a shorter phrase says the same thing, and don't hyphenate an adjective pair sitting in predicate position where no hyphen is needed.
Detect: Replace padding phrases and formulaic connective bundles with their plain equivalent, and remove hyphens from adjective pairs used predicatively.

### One connective device at a time
Prevent: Vary how sentences connect and land, periods, conjunctions, commas, as the content calls for, rather than routing nearly every sentence through the same device, a colon or a clipped fragment.
Detect: Find runs where most sentences pivot on a colon or land as a stacked clipped fragment, and restore ordinary conjunctions and full sentences so only a genuinely earned instance remains.

### Earn the aphorism
Prevent: State an actual, checkable observation instead of reaching for a tidy aphoristic template that sounds insightful by shape alone.
Detect: Find sentences that fit a generic template ("X is the Y of Z," "X becomes a trap") and check whether a specific claim backs them up; if not, replace with the concrete observation or cut the line.

### Match structure to the actual ask
Prevent: Size the response to what was actually asked. A yes/no or single-fact question gets a direct answer, not an intro, several headed sections, and a closing summary imposed by habit, and a heading should be followed by real content, not a sentence that just restates it.
Detect: Find essay-shaped answers to simple questions, a formulaic closing line that concedes challenges before declaring an optimistic future regardless of subject, and headings immediately followed by a restatement of themselves, and cut the imposed structure back to what the content actually supports.

### Answer without the wrapper
Prevent: Open with the actual content and stop when the content ends. Don't spend a sentence announcing that an answer is coming, praising the question, or signing off with a chat pleasantry.
Detect: Cut opening throat-clearing (fake-authority framing, meta-announcements, fake-candid hooks), trailing chatbot sign-offs, and reader-directed praise, leaving only the substance.

### Hedge in proportion to confidence
Prevent: Hedge only as much as the actual uncertainty warrants: commit to a position when the evidence supports it, and name real uncertainty plainly instead of either stacking qualifiers until the claim says nothing or stating everything with more confidence than it deserves. Where the register calls for it, also let genuine personal engagement through, a booster, an attitude marker, a rhetorical question, a first-person "I think," rather than defaulting by habit to flat, textureless exposition.
Detect: Find stacked hedges that add up to no real claim and collapse them to one honest confidence level, find flat assertions stated with more certainty than warranted and add the qualifier they need, and find prose that reads uniformly flat and impersonal no matter the register, restoring the personal texture the context supports.

### Keep one register, matched to context
Prevent: Match the register to what the piece actually is, a Slack message reads differently than a report, instead of defaulting to one generic explainer voice, and hold that register steady across a single document rather than drifting between sections.
Detect: Find text that reads the same regardless of medium or audience, or a document where tone or quality shifts abruptly between sections, and even it out to one register appropriate to the content without erasing genuine texture the source already had.

### Describe what it is, not what changed
Prevent: Describe a subject in its own current terms, unless the surrounding content is actually a changelog or release note, in which case what changed is the point.
Detect: Find prose that explains something by narrating what it replaced or removed, and rewrite as a direct description of the current state unless the format genuinely is a changelog.

### Let fiction's theme stay implicit
Prevent: When writing fiction, let theme and meaning emerge from action and detail, and let tension rise and fall unevenly rather than escalating on one flat plane.
Detect: In fiction, find sentences that announce the story's own moral or meaning outright and cut them, trusting the preceding action to carry it.

### Sentence-case, properly nested headings
Prevent: Write headings in sentence case, and nest heading levels in order without skipping one or dropping a redundant rule directly before a heading.
Detect: Fix headings written in title case, correct heading-level jumps to proper nesting, and remove a horizontal rule sitting immediately before a heading.

### Emphasis markup only where it's earned
Prevent: Use bold or italics only where the target format expects them and only to mark something that genuinely needs emphasis, not as a mechanical scan-key habit, and write a bulleted explanation as a plain sentence or plain bullet rather than a bolded term followed by a colon, or a bolded opening sentence followed by the text that explains it.
Detect: Unbold terms bolded purely for scannability, convert "term, colon, explanation" bullets into plain prose or plain bullets, and strip stray emphasis markup from output whose target format doesn't use it. The bolded lead-in counts whether it ends in a colon or a period, and whether it is a term or a full sentence; a run of them is a heading structure in disguise, so either make them real headings or unbold them all.

### Attribute and cite only what's real
Prevent: Attribute a claim to the specific source that actually supports it, never to an unnamed collective, and include a citation only when you can confirm it resolves to, and matches, the claim it's attached to.
Detect: Replace vague collective attributions with the specific named source or drop the claim, and check that links, DOIs, and ISBNs resolve and match what they're cited for, fixing or removing any that don't.

### Don't invent when the material runs out
Prevent: When real information runs out, say so plainly instead of inventing plausible-sounding filler, and don't stretch a subject's coverage with a list of mentions that never engages with what was actually said.
Detect: Find invented biographical or factual detail dressed up as fact once sources run out and replace it with an explicit statement that the information isn't available, and cut lists of outlets or mentions that carry no actual content.

### Older-model tells
Detect: A passive-voice-heavy sentence used to be a reliable AI tell; current instruction-tuned models actually produce agentless passives at roughly half the human rate, so treat passive density in old or suspect text as weak, mostly-historical evidence rather than proof, and rewrite for a clear actor only where doing so genuinely improves the sentence.
