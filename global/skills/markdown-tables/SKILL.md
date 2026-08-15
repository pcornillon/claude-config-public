---
name: markdown-tables
description: Default formatting conventions for any Markdown table — README files, design docs, status pages, work logs, project notes, codification appendices, any .md file with a table. Produces clean rendered output: correctly sized columns, no zebra striping, no internal borders between continuation lines, code cells without the default gray background, long paths that wrap at folder boundaries rather than mid-filename, and content packed efficiently inside cells. Apply whenever creating, editing, adding rows to, or restructuring a Markdown table, unless the user explicitly opts out for a specific table.
---

# Markdown tables — default conventions

This skill captures the table-formatting conventions the user has
established for their Markdown documents.  Apply them by default to
every table you create or edit in a `.md` file.  These are the
defaults for *all* of the user's Markdown work; deviate only when
they explicitly ask for a different style on a specific table, or
when the table is so trivial that markdown pipe syntax is clearly
fine (a two-row, single-value-per-cell example inside a doc).

## Why these conventions exist

Markdown's pipe-syntax tables (`| a | b | c |`) compile to one
`<tr>` per source line, which causes a cluster of rendering
problems the user dislikes:

1. **Continuation rows look like separate entries.**  If a cell
   has multi-line content (a long label that needs to wrap, or a
   styled code string that spills onto multiple lines), the
   markdown source has to repeat the `| … |` line for each
   visual line — and the renderer draws a horizontal border
   between every one of them.  What is logically one entry
   becomes several visually separated rows.
2. **Zebra striping fires on those continuation rows.**  Most
   Markdown renderers apply `tbody tr:nth-child(2n)` background
   shading, so half of those spurious rows pick up a gray
   background.
3. **Inline `` `code` `` spans pick up a gray cell background**
   from default renderer CSS.  Inside a small table cell this
   looks like a smudge.
4. **Long paths force columns to be impossibly wide, or worse,
   break mid-filename.**  The auto-layout algorithm gives the
   column with the longest atomic content as much width as that
   content wants, squeezing every other column.  If the long
   content is a path with no break opportunities, the renderer
   either makes one column dominate or — when `overflow-wrap`
   is engaged — breaks the path character-by-character.
5. **Tables can be different widths on the same page**, which
   looks asymmetric and unprofessional when several tables
   appear in sequence.

Switching from pipe syntax to a raw `<table>` block with the
conventions below solves all of these.  Each logical entry is
exactly one `<tr>`, row backgrounds are explicitly transparent,
the `<code>` background is stripped, paths break at folder
boundaries when they have to, and every table fills the same
horizontal width.

## The conventions

### 1.  Use raw HTML `<table>` instead of pipe syntax

Reach for HTML whenever any of these is true:

- A label or content cell would otherwise wrap inside the cell
  (a multi-word label that doesn't fit the column width, a long
  code string that needs to be broken at natural delimiters,
  a description that spans several visual lines).
- You want to suppress the alternating-row zebra striping.
- You want the rendered table to fill the full text width of the
  document rather than only the width its content forces.
- The table contains paths, identifiers, or other long atomic
  strings that need wrap control.

For genuinely simple tables — a 1-D list of `key | value` pairs,
or a tiny lookup with single-word cells everywhere — pipe syntax
is fine and easier to scan in source.  Default to HTML when in
doubt; the user prefers consistency.

### 2.  Skeleton

```html
<table style="width: 100%; table-layout: fixed;">
<colgroup>
<col style="width: …;">
<col style="width: …;">
…
</colgroup>
<thead>
<tr>
<th align="left">Column 1</th>
<th align="left">Column 2</th>
<th align="left">Column N</th>
</tr>
</thead>
<tbody>
<tr style="background:transparent;">
<td>…</td>
<td>…</td>
<td>…</td>
</tr>
…
</tbody>
</table>
```

One `<tr>` per logical entry.  Multi-line content within a cell
uses `<br>` for line breaks — never a second `<tr>`.

The `table-layout: fixed;` declaration and the `<colgroup>` may
be omitted for very simple cases where every column has
single-word content and auto-layout will obviously do the right
thing.  For everything else they are required (see §7 and §8).

### 3.  Tables fill the available text width

Always include `style="width: 100%;"` on the `<table>` element.
This makes every table on the page span the same horizontal
distance, which looks symmetric when multiple tables appear in
sequence.  Without it, tables size themselves to their longest
content, so a small two-row table next to a large one looks
narrower and visually broken.

### 4.  Suppress row striping

Add `style="background:transparent;"` to *every* `<tr>` in
`<tbody>`.  This overrides the renderer's default
`tbody tr:nth-child(2n)` background.

The header `<tr>` doesn't need it — header styling is
intentional and typically does want a distinct background.

In some renderers — notably GitHub web — `tbody tr:nth-child(2n)`
is declared with `!important` and inline styles can't override
it.  Accept that limitation; the inline style is still the right
thing to ship because it works in most renderers (VS Code
preview, Obsidian, local Markdown viewers, the static-site
generators the user uses).

### 5.  Two `<code>` styles inside cells: basic and path-style

Inline code inside a cell needs the renderer's default `<code>`
styling stripped — the gray background, the small padding, the
thin border or rounded corners some renderers add.  Use one of
two style attributes, depending on what's *inside* the `<code>`:

**Basic style** — for atomic identifiers (filenames without `/`,
variable names, function names, anything that has no internal
break opportunities and should stay intact on one line):

```html
<code style="background:transparent; padding:0; border:none; border-radius:0;">…</code>
```

**Path style** — for paths and other content with `<wbr>` break
opportunities (see §7).  Adds two more declarations on top of
the basic style:

```html
<code style="background:transparent; padding:0; border:none; border-radius:0; white-space: normal; overflow-wrap: anywhere;">…</code>
```

**Why two styles?**  The `<code>` element in many renderers
defaults to `white-space: nowrap`, which prevents *any* wrapping
inside it — including at `<wbr>` opportunities.  The
`white-space: normal` override lets `<wbr>` work.  The
`overflow-wrap: anywhere` override tells the table-layout
algorithm that the cell's min-content width can be small, which
prevents the cell from claiming the full content width and
squeezing its siblings.

**These two declarations are tied to having `<wbr>` content
inside the `<code>`**, because together they say "break at
`<wbr>` first, anywhere else only as a last resort."  Without
`<wbr>` opportunities, `overflow-wrap: anywhere` collapses to
just "break anywhere" — which destroys atomic identifiers
character-by-character when the column gets narrow.  For
atomic-identifier cells, use the **basic** style and let the
column's preferred width force enough room for the identifier
to fit intact.

### 6.  Column widths: atomic-token constraint

For source readability — and to satisfy the algorithm with
`table-layout: fixed` — size each column to accommodate the
**widest atomic token** that appears anywhere in the column
(header included).

By **atomic token** I mean an unbroken character sequence that
should not be split across lines — what a human would read as a
single "word" even when it contains punctuation.  Specifically,
treat these as one token:

- Plain words: `Terminator`, `Rectangle`.
- Numbers with grouping or decimal punctuation, optionally with
  units or currency: `$10,000`, `3.14159`, `42 km`, `−0.5°C`.
- Numbers with space-separated thousands like `36 058` — these
  are atomic too; write the separator as `&nbsp;` so the
  renderer can't break the number (see §12).
- File names with extensions: `build_oinfo_file.m`, `README.md`,
  `Q4_sales_FINAL.xlsx`.
- Dotted, dashed, or underscored identifiers: `snake_case_name`,
  `kebab-case-name`, `module.submodule.function`.
- Email addresses and URLs: `user@example.com`,
  `https://example.com/path`.
- Hyphenated compounds the user clearly wants kept together:
  `multi-word-label` (when written with hyphens rather than
  spaces).

A *space* is the canonical token separator.  So
`Process / data step` is three tokens (`Process`, `/`,
and `data step` which itself splits at the internal space).  A
*slash with spaces around it* counts as its own token.

**The constraint with `table-layout: fixed` is hard, not soft:**
each column's percentage width × the table's rendered width must
be at least as wide as the longest atomic token in that column.
If you can't satisfy this for every column inside the available
table width, the table needs restructuring (see §11).

Multi-word labels in headers and cells wrap onto multiple lines
using `<br>` at natural boundaries — typically after `/`, after
a space, or between a noun and its adjective.  This is
particularly useful for header cells: `Source<br>copied` for a
column with single-character flag values whose header is two
words wider than the values.

**Worked example.** The widest atomic token in a "Dependency"
column is `initialize_satellite_specific_parameters.m` (42
characters).  At a typical 1000-pixel page rendering, the
column needs at least 42/100 = 42% of the table width to fit
that filename on one line.  Set the column to 45% or 50% for
breathing room.

When adding a row later, recompute the widths.  If the new
entry contains a wider atomic token than anything currently in
that column, widen the column — which may mean *un*-wrapping a
previously wrapped label.  This keeps the source visually
consistent.

### 7.  Insert `<wbr>` after every `/` in long paths

Paths inside `<code>` cells are atomic tokens (no internal
spaces), so the renderer will refuse to wrap them and will make
the containing column inconveniently wide.  When a path is more
than about 30 characters, insert `<wbr>` after every `/` to
give the renderer permission to wrap at folder boundaries.

Do **not** insert `<wbr>` at `_`, `-`, `.`, or any other
character that lives *inside* an identifier or filename.  Those
are internal to logical names and breaking there reduces
readability without a corresponding gain.

`<wbr>` is the HTML "word-break opportunity" element.  It's
self-closing, takes no attributes, and is invisible in
rendered output: the renderer uses it only if wrapping is
needed.  Cross-renderer support is solid.

**Example transformation.**

```
appendices/A_orbit_construction/build_oinfo_file/prompts/build_oinfo_file_1_2026_05_21-prompt.md
```

becomes

```
appendices/<wbr>A_orbit_construction/<wbr>build_oinfo_file/<wbr>prompts/<wbr>build_oinfo_file_1_2026_05_21-prompt.md
```

In rendered output, when there's room the whole path stays on
one line.  When the column is squeezed, the renderer breaks
after one of the `/` slashes — at a folder boundary — and the
final filename segment stays intact.

Pair `<wbr>`-bearing paths with the **path style** of §5.
Without `white-space: normal` and `overflow-wrap: anywhere`,
the renderer's default `<code>` styling prevents `<wbr>` from
firing.

### 8.  Use `table-layout: fixed` with `<colgroup>` for any non-trivial table

Auto-layout (the default) gives each column its preferred
content width when there's room, and falls back to ad-hoc
shrinking when there isn't.  For tables with even mild
heterogeneity — one wide column with paths, several narrow
columns with flags, a medium column with prose — auto-layout
allocates space badly, especially when `overflow-wrap: anywhere`
is in play (the algorithm can decide a wide column's
min-content is a single character and squeeze it accordingly).

The reliable fix is `table-layout: fixed` plus an explicit
`<colgroup>` that names each column's width as a percentage.
This takes the allocation decision out of the renderer's hands.

`<colgroup>` syntax (note: `<col>` elements are self-closing,
in source order, one per column):

```html
<colgroup>
<col style="width: 22%;">
<col style="width: 65%;">
<col style="width: 13%;">
</colgroup>
```

The percentages must sum to 100.

For a table where every column has roughly equal-importance
content and only narrow-token cells, you may omit the
`<colgroup>` and rely on the renderer's equal-distribution
default for fixed layout — but pick the explicit `<colgroup>`
when in doubt; it's predictable.

### 9.  Width allocation: hardest-to-wrap content wins

When picking column percentages, allocate based on the cell
content that is *hardest to wrap cleanly*, not on the median
cell.

In practice, in a table with one "wide content" column
(typically paths with `<wbr>`) and other "easy content"
columns (prose with abundant spaces, short flags, single
numbers), give the wide-content column the bulk of the width
and absorb the wrapping cost in the easy-content columns.

**Example.**  A 3-column table with Artefact / Path / Bytes,
where Path can be up to ~135 characters and the longest
filename inside a Path is 58 characters: give Path 65% width
(enough that the 58-char filename fits at typical viewports),
Artefact 22% (its descriptions wrap fine at spaces), and Bytes
13% (its numbers and the "Size (bytes)" header fit
comfortably).

The temptation is to give every column equal width or to
allocate proportionally to median content width.  Resist it.
The visible cost of "Manuscript overview" wrapping onto two
lines is much less than the visible cost of a filename
breaking character-by-character.

### 10.  Pack long cell content at natural delimiters

For cells with structured content (drawio style strings,
comma-separated lists, semicolon-separated declarations), split
at the natural delimiter and pack as many complete fragments
per visual line as the column width allows.

Use `<br>` between fragments inside the same cell — never start
a new `<tr>`.  If the content is code, each line gets its own
`<code>` wrapper.

**Example.**  A drawio style with seven `;`-separated fragments
packed into two visual lines:

```html
<td>
<code style="background:transparent; padding:0; border:none; border-radius:0;">rounded=0;whiteSpace=wrap;html=1;fillColor=#f5f5f5;strokeColor=#666666;</code><br>
<code style="background:transparent; padding:0; border:none; border-radius:0;">align=left;dashed=1;</code>
</td>
```

The break point is the author's call; aim for "as many complete
fragments as fit" rather than splitting mid-fragment.

Note that the cells here use the **basic** style of §5, not the
path style — there are no `<wbr>` opportunities inside the
fragments, and the breaks are manual via `<br>`.

### 11.  Check for column redundancy before creating a table

If one column's content is *contained* in another column's
content — for example, a Dependency column whose value is a
filename, next to a Path column whose tail is the same
filename — drop one of them.  The freed horizontal space lets
the remaining columns lay out cleanly without restructuring.

Equally important: when you drop the redundant column, **keep
the side that surfaces the most-relevant identifier at the top
level**.  Burying the filename inside a 135-character path is
the worst of both worlds: the redundancy is gone but the
reader has to mentally parse the tail of every path to find
the name.  Better is to keep the filename in its own column
and put only the *folder* in the path column.  Header that
column "Folder containing the function" (or similar) to make
the truncation explicit.

**This is the principle behind §6's atomic-token constraint:**
if you can't satisfy the constraint for every column inside
the available width, the table is asking for too much
horizontal space, and the right answer is usually to remove or
collapse a column rather than to shrink columns past their
content's minimum width.

### 12.  Numbers, dates, and other punctuation-bearing tokens

Treat these forms as atomic, using HTML entities to suppress
unwanted breaks where necessary:

- **Numbers with space-separated thousands** (`36 058`,
  `1 234 567`): write the separator as `&nbsp;` so the
  renderer can't break the number across lines.  Example:
  `36&nbsp;058`.
- **Hyphenated dates** that shouldn't break in the middle
  (`2026-05-20`): typically the surrounding context provides a
  better break point (the space before `(2026-05-20)`).  If the
  renderer treats hyphens as soft breaks anyway, wrap the
  whole token in a nowrap span:
  `<span style="white-space: nowrap;">(2026-05-20)</span>`,
  or replace the hyphens with non-breaking hyphens
  (`&#8209;`).  Reach for these only when you've actually seen
  the date break in rendered output; don't pre-emptively
  litter the source.
- **Currency amounts and decimal numbers** (`$10,000`,
  `3.14159`): the comma and decimal point already act as
  glue; no extra entities needed.

### 13.  Mixed code-and-prose cells

A cell may legitimately contain both code-like fragments and
plain prose between them — for example, "`code/PROVENANCE.md`
(`## anchor` block)" where the path and the anchor are both
code-like but the parenthetical glue is not.

Wrap each code-like fragment in its own `<code>` element with
the appropriate style (basic for atomic identifiers, path
style for `<wbr>`-bearing paths) and leave the connecting
prose as plain text in the same `<td>`:

```html
<td>
<code style="background:transparent; padding:0; border:none; border-radius:0;">code/PROVENANCE.md</code>
(<code style="background:transparent; padding:0; border:none; border-radius:0;">## build_oinfo_file.m</code> block)
</td>
```

### 14.  Numeric column alignment

- **Right-align** columns containing multi-digit numbers
  (file sizes, commit counts where values reach 2+ digits,
  monetary amounts).  Right alignment makes the digits line up
  by place value, which is the conventional reading expectation
  for numbers.
- **Center-align** columns containing single-character flags
  (`y`/`n`, ticks) and single-digit counters.  Centering looks
  more polished than left-alignment for one-character content.
- **Left-align** prose and code columns by default.

Apply alignment on both `<th>` and `<td>` (`align="right"`,
`align="center"`, `align="left"`) so the header sits over its
column the same way the values do.

### 15.  Multi-content-column tables

If a table has more than one "wide content" column (e.g., a
side-by-side comparison of two code fragments, or a
before/after schema), default to giving each wide column an
equal share of the available width.  This is a judgment call
rather than a hard rule — let the content guide you, and ask
the user if the right split isn't obvious.

## Worked example

A 3-column "Artefact / Path / Bytes" table demonstrating most
of the conventions: full-width fixed layout with explicit
column percentages, transparent row backgrounds, the
basic/path `<code>` style distinction (path style for paths
with `<wbr>`, basic style for the short `STATUS.md`), `<wbr>`
inserted after every `/` in long paths, right-aligned numbers
with `&nbsp;` between digit groups, mixed code-and-prose in
the "PROVENANCE entry" row.

```html
<table style="width: 100%; table-layout: fixed;">
<colgroup>
<col style="width: 22%;">
<col style="width: 65%;">
<col style="width: 13%;">
</colgroup>
<thead>
<tr>
<th align="left">Artefact</th>
<th align="left">Path</th>
<th align="right">Bytes</th>
</tr>
</thead>
<tbody>
<tr style="background:transparent;">
<td>Source copy</td>
<td><code style="background:transparent; padding:0; border:none; border-radius:0; white-space: normal; overflow-wrap: anywhere;">code/<wbr>build_oinfo_file.m</code></td>
<td align="right">36&nbsp;058</td>
</tr>
<tr style="background:transparent;">
<td>PROVENANCE entry</td>
<td><code style="background:transparent; padding:0; border:none; border-radius:0;">code/PROVENANCE.md</code> (<code style="background:transparent; padding:0; border:none; border-radius:0;">## build_oinfo_file.m</code> block)</td>
<td align="right">—</td>
</tr>
<tr style="background:transparent;">
<td>Prompt</td>
<td><code style="background:transparent; padding:0; border:none; border-radius:0; white-space: normal; overflow-wrap: anywhere;">appendices/<wbr>A_orbit_construction/<wbr>build_oinfo_file/<wbr>prompts/<wbr>build_oinfo_file_1_2026_05_21-prompt.md</code></td>
<td align="right">185</td>
</tr>
<tr style="background:transparent;">
<td>STATUS.md row</td>
<td><code style="background:transparent; padding:0; border:none; border-radius:0;">STATUS.md</code></td>
<td align="right">—</td>
</tr>
</tbody>
</table>
```

## When *not* to apply

- The user explicitly tells you to use markdown pipe syntax for
  a specific table ("don't bother with the HTML conventions
  here").
- The table is a throwaway inside a chat message or a draft —
  the conventions are about persistent documents, not ephemera.
- A table is genuinely small (≤ 3 rows, single-value cells, no
  code content) and pipe syntax is more readable in source.

## Updating this skill

These conventions are the user's own and may evolve.  When the
user asks you to revise a table in a way that doesn't fit the
existing rules, ask them whether the new pattern should be
captured as a permanent change to this skill — and if so,
update this `SKILL.md` (or, for project-specific overrides,
the relevant project's `CLAUDE.md`).

When applying the skill to an existing document for the first
time, always back up the original (`<filename>_pre-skill.md` in
the same folder) so the user can diff the two and decide
whether the new rendering is an improvement.

## Source verbosity

These conventions produce HTML source that is 5–10× longer
than the equivalent pipe-syntax table.  This cost is real and
not pretty to look at in raw markdown.  Two consolations:

- The rendered output is what the user actually reads day to
  day; the source is read mainly by you (the agent) when
  editing.
- Most of the verbosity is in repeated `<code>` style
  attributes.  If a future renderer supports `<style>` blocks
  inside markdown documents reliably, this can be collapsed by
  defining CSS classes; until then, repetition is the price.
