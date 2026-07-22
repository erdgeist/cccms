## The head / draft / autosave / translation lifecycle

### Era 1 — the original design (2009, `doc/README_FOR_APP`).

Two layers only: `head` (the published, public revision) and `draft`
(a full copy of head's content, created the moment someone starts
editing).

No separate lock concept. The draft's *author* was the lock.
Pessimistic, one editor at a time, enforced by ownership rather than a
distinct column. An author could withdraw authorship (the draft
becomes author-less, open for someone else to pick up) or discard the
draft entirely, reverting to head.

Admins could override any lock or remove any stuck draft on another
editor's behalf. No autosave.

Globalize wasn't part of the permission model (`Permission` grants
admin rights to steal a lock a node.

### Why a third layer got added.

Under the original model, the moment someone started typing, a real,
numbered revision already existed: `acts_as_list` assigns revision
numbers at creation, scoped to `node_id`.

A speculative edit (open the editor, type a few words, close the tab)
still counted as a real Draft, and a real future revision if it were
ever published.

The rebuild introduced `autosave` as a genuinely separate layer: the
same `Page` model, but created with `node_id: nil` specifically so
it's excluded from `Node#pages`, the actual revision list.

Typing progress survives a crash or a closed tab, but nothing becomes
a real revision until the editor deliberately saves, which promotes
the autosave's full content, wholesale, into the draft layer via
`clone_attributes_from`.

A canonical six-state reference table (head / draft / autosave present
or absent, and what each combination permits) lives alongside the
model code as the authority for any future work on this lifecycle.

### Translations (Globalize), layered on top

The governing principle for admin views from that rebuild:

*presentation locale* (what language the admin chrome renders in) and
*content-target locale* (which translation a given screen reads or
writes) are separate concerns that must never share a mechanism.

The route's `:locale` segment governs only the former. A locale is
either the default one — edited exclusively through the primary node
editor, pinned via `Globalize.with_locale` regardless of what the
route happens to say, so a stray `/en/` URL can't silently edit the
German content (as has been the case before the rewrite in 2026), or
one of the non-default locales, edited exclusively through a
Translations sub-resource under a deliberately distinct route
parameter (`translation_locale`), chosen specifically because it must
never leak into `default_url_options` the way the chrome locale does.
Never both paths for the same locale.

For now, admin chrome language stays tied to the route locale for now.
A per-editor preference column was considered and set aside as
revisit-later, not built.

Translations carry no independent publish state: a translation goes
live exactly when the draft containing it is promoted to head, same as
everything else in that `Page` row. Both a per-translation
`published_at` and full per-locale draft/head/autosave parity with
`Node` were considered and rejected as unneeded machinery absent a
real editorial need for staggered release timing.

## Events and the calendar

### Problem

Calendar entries required an internal Node — every event needed a page
somewhere in the tree. Editors avoided this: either the updates stream
absorbed non-news content, or a page got created with no natural place
in the navigation. The calendar widget went dormant rather than get
used under those terms.

### Rebuild.

The Event model was rewritten around the RRULE humanizer
(`app/models/concerns/rrule_humanizer.rb`) and a picker UI bound to it
by a deliberate scope rule: the picker only generates or reads back
RRULE shapes the humanizer can also render as prose. A picker that
could express more than the humanizer can describe would let an editor
create a schedule that renders as blank text on the public page —
worse than a raw string the editor had to type by hand.
`Event#node_id` became optional, so an event can point outward (an
external URL) instead of requiring a page. This is what made reviving
the calendar possible at all.

### The "where to put an event" problem

Once events no longer needed a node, turning the calendar on directly
would have meant every chapter's regular open evening becoming an
entry — a handful of one-off items buried under dozens of recurring,
low-signal rows.

### Resolution:

Two widgets, not one:

- `open_erfas_today` took the recurring, date-filtered case — which
  chapters are open today. Its label went through rejected drafts
  before landing on phrasing that admits it's a curated sample, not a
  complete listing.
- `div#frontpage_calendar` was reserved for the one-off case —
  conferences, memorial gatherings. Its CSS carries an unconditional
  `display: none` with no override anywhere in the stylesheet — not a
  bug, a widget staged for a UI that hasn't been built yet.

## The action log (`NodeAction`)

### Origin

The action log grew directly out of an audit of what timestamps
actually mean: Two things were missing in the old model: no record of
who actually clicked Publish (`page.editor` reflects the last content
save, not necessarily that specific act), and the dashboard's
recent-changes widget was actively wrong, showing an unrelated
in-progress draft's byline next to a timestamp that didn't correspond
to why the node appeared on the list at all.

The log was designed to fill the gap and to answer "what did people
do," a question the existing timestamp fields were never designed to
answer.

### Governing principle

A derived log is only as reliable as the discipline that maintains it.

Named explicitly before any code was written, not discovered afterward.
Three ways it can drift:

1. A future code path can simply forget to write to it — this project
   had already found that exact shape twice (`wipe_draft!`'s ungated
   branch; `Page.aggregate` silently ignoring a `conditions=` argument).
2. If the log write and the actual mutation aren't in the same
   transaction, they can diverge on a crash. Resolved by writing from
   *inside* the model methods themselves (`autosave!`, `save_draft!`,
   `publish_draft!`, `trash!`, `destroy!`) rather than from the
   controllers that call them — every future caller is covered for
   free, the same reasoning already proven by the JS-autosave work.
3. It can never retroactively reconstruct anything from before it
   existed — addressed deliberately by the backfill (below), not
   ignored.

### Avoiding noise

A draft save or publish that produces no visible difference shouldn't
create a visible log entry. Solved by reusing
`Page#diff_against` / `has_changes_to?` — comparisons that already
existed and were already tested — rather than inventing new diffing
logic for the log to own.

### The verb vocabulary

Firstly, the log deliberately excludes locks (transient, no history
value), autosave and draft-saving itself (exactly the noise the log
exists to filter out), and tag/asset/event edits made *on a draft*
(those will later surface as changed-flags at publish time, which
is when they become real).

Deliberately included, on reflection: reverts and discards (arguably
more worth tracking than promotions:  "who discarded this work, and
when" is the fact someone would actually go looking for), shared
preview link generation and revocation (security-relevant, handing
unpublished content to an outsider), and slug/path changes
(link-breaking, earns its own record separate from ordinary edits).

### Rollback isn't a separate verb.

`restore_revision!` writes a `publish` entry with a discriminator
(`via: "revision"` instead of `via: "draft"`) rather than its own
vocabulary. One verb, one meaning ("a page got promoted to head"),
distinguished by how it got there.

### Backfill

Historical entries mirror the live vocabulary exactly. Diff content
(what actually changed) is computed from the real historical revision
data, since consecutive `Page` rows already existed to compare — only
the actor and the timestamp are ever inferred, each backfilled entry
carrying an `inferred_from` field naming the specific heuristic used
(e.g. "from a page revision," "from `published_at`"). A `null`
`inferred_from` means the entry was witnessed live, not reconstructed —
so the log can always answer, for any entry, how much to trust it.

### The full metadata contract per verb

`create`, `publish`, `move`, `trash`, `restore_from_trash`, `destroy`
— lives as a code comment directly above `record!` in
`app/models/node.rb`. That's the authoritative, current version; this
entry explains why it's shaped the way it is, not what it says field
by field.

### Retired code

The timestamp-driven surfaces this replaced — the dashboard widget
and the nodes#recent page — are gone; admin/log is the sole
recent-activity view.

## Attachments: images and PDFs

Originally attachments were images only; PDFs are now first-class,
and the subsystems below treat both through one mechanism.

Every attachment is an Asset joined to pages via RelatedAsset. The
starred attachment ("headline") becomes the page's face on the
public site; if none is starred, visitors get a link to browse all
attached images instead. PDFs are headline-eligible because the
standard raster variant set is generated for them from the
document's first page (ImageMagick with Ghostscript), so aggregators
and teasers need no special case.

Presentation differs by type at the last step only: an image
headline opens in the lightbox, a PDF headline renders as a document
card whose click delivers the document itself — a lightbox showing a
raster of page one would misrepresent what the asset is. Pages list
attached documents separately from the image gallery.

Credit display (photographer, license, attribution) applies to
images only; the vocabulary describes photographs and is deliberately
not rendered for PDFs. Admin asset search matches filenames as well
as names, since document filenames carry meaning in a way image
filenames rarely do.

The test suite runs against isolated storage and never touches the
real upload tree; keep it that way when adding asset code.
