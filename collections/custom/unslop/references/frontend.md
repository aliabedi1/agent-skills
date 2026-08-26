# Frontend design rules

Rules for the visual and interaction design of generated frontends: layout, color, type, components, motion, and how copy is placed in markup and styles.

## Ban list

**Colors**
- `#8b5cf6`, the reflexive purple/violet accent hex often paired with cyan on dark backgrounds. Pick an accent grounded in the actual brand instead.
- `#F4F1EA`, the reflexive warm cream background hex. Same fix.

**Symbols**
- `✓`, `✅`, `⚙️`, `📊`, and similar emoji used as navigation icons, feature markers, or list bullets. Use a real icon component instead.

**CSS**
- `transition` or `animation` declared on `width`, `height`, `padding`, or `margin`. Animate `transform`, `opacity`, or a grid-template-rows trick instead; these force a layout recalculation every frame.

## Rules

### Ground the design in the subject
Prevent: Derive palette, motif, imagery, and overall page shape from the actual brand, product, or content in front of you. Avoid reaching for a recognizable convergent default: a purple or cream-and-terracotta or dark-navy-plus-neon palette, a centered hero over a tri-column icon-card grid, a generic "editorial" or broadsheet template, or a stock-style hero photo composition borrowed from an unrelated category.
Detect: Check whether the palette, layout shape, aesthetic, or hero image matches one of these well-known generic defaults with no connection to the subject. If it does, replace it with a choice built from the subject's own materials, colors, or context.

### Make decoration earn its place
Prevent: Add glow, blur, glassmorphism, or a gradient fill only where it marks something specific on the page, such as a live state or the one true focal point, and keep other surfaces flat. Commit to at most one deliberate use of depth rather than spreading it across every element or dropping it everywhere at once.
Detect: Find blurred or glowing shapes, frosted-glass panels with nothing layered behind them to justify the blur, or gradients (or a total absence of any) applied uniformly across the page. Remove the unmotivated instances or consolidate to the one element that actually needs it.

### Treat the hero headline as a real choice
Prevent: Pick a typeface, or a considered pairing, suited to the actual content instead of reaching for the same handful of default web fonts with no pairing at all. Keep one consistent type treatment across a single headline rather than switching styles mid-sentence for emphasis, and size the headline to match how much it actually says, moving any longer explanatory sentence to a smaller subhead.
Detect: Find a page whose headline, nav, and body all share one unpaired default typeface, a headline that switches into italic serif for a single word while the rest stays roman sans, or a full grammatical sentence blown up to dominate the hero viewport. Fix the pairing, remove the mid-sentence switch, or split the sentence into a short headline plus a subhead.

### Keep text and structure accessible
Prevent: Keep body and hero text at or above WCAG AA contrast, 4.5:1 or 3:1 for large text, against its background. Keep heading levels sequential with no level skipped, no matter how the visual hierarchy looks.
Detect: Compute the contrast ratio of text against its background and raise it wherever it falls short. Check the heading outline for a skipped level and insert or retag the missing one without changing what renders visually.

### Use real assets, not placeholders
Prevent: Only add an image or illustration element when a real asset actually exists for it. When no real illustration is available, use an existing icon or illustration system rather than hand-coding a crude decorative SVG to fill the space.
Detect: Find empty, missing, or placeholder image src values, or a hand-drawn blob-path SVG standing in for real art, and either supply the real asset or remove the element instead of leaving a stand-in.

### Keep containers from clipping or overflowing
Prevent: Size containers so their content fits without triggering unintended scroll, and give elements meant to escape their parent, such as tooltips or dropdowns, an ancestor that will not clip them.
Detect: Find a parent with hidden overflow clipping an absolutely positioned child that was meant to escape it, or content wider than its container creating unwanted horizontal scroll. Fix the containment relationship without touching the visual design.

### Set type for reading comfort
Prevent: Set body text at a comfortable size and line-height, roughly 16px and up with 1.3x line-height and up, keep letter-spacing near normal for running text, and reserve wide tracking and all-caps for short labels rather than paragraphs. Give text real breathing room through padding and a sensible max-width, pair any justified text with hyphenation, make a real size and spacing difference between heading and body levels instead of a flat scale, and vary the margin or gap between elements by how closely related they are, a tight gap between a title and its subtitle, a wider one between separate cards, rather than applying one flat spacing value everywhere so that grouped content actually reads as grouped.
Detect: Check font-size, line-height, letter-spacing, padding, max-width, text-transform, text-align, and margin or gap against these thresholds wherever body copy or a type scale appears, including whether spacing between elements tracks how closely related they are rather than repeating one uniform value regardless of relationship, and adjust whichever value falls short without touching the words or the content.

### Use containers with intent
Prevent: Choose border, radius, and shadow values per component's actual role instead of pasting one combination onto every element on the page. Add a colored accent border only when it signals something specific about that card, and use spacing and typography rather than nesting a second bordered card inside the first.
Detect: Find identical radius, shadow, or border values applied uniformly across unrelated components, including an unmodified component-library default, a thick single-edge colored border unrelated to the card's content, or a card nested inside another card. Adjust the values per element or collapse the nested card into spacing and type.

### Make structural decoration true
Prevent: Use numerals, kickers, badges, stat callouts, and repeated bullet marks only when they encode something real and specific to the content in front of you. When nothing real backs the slot, leave it out instead of filling it with a generic placeholder or an invented-sounding number.
Detect: Find sequential-looking numerals or uppercase kickers repeated section after section with no real sequence behind them, an announcement badge with no real announcement elsewhere on the site, a stat banner untraceable to a real figure, or a checkmark bullet applied identically to every line whether or not it is a real differentiator. Replace each with the real content, a real distinction, or nothing at all.

### Make motion deliberate
Prevent: Either skip animation or build one orchestrated sequence that actually serves the page, rather than defaulting to the same fade-and-rise on every section and card. Give an image a hover transform only when the image itself is interactive.
Detect: Find the same opacity-plus-translateY scroll reveal applied to every section, card, and list item, or a scale or rotate hover transform on a non-interactive product or hero image. Remove it or replace it with something considered and purposeful.

### Older-model tells
Detect: Springy, elastic bounce easing on ordinary button or element transitions reads as a dated texture from earlier interface-motion trends. Replace it with a quick, simple ease-out.
