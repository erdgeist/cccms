## The head / draft / autosave / translation lifecycle

### Era 1 — the original design (2009, `doc/README_FOR_APP`).

Two layers only: `head` (the published, public revision) and `draft`
(a full copy of head's content, created the moment someone starts
editing).

No separate lock concept. The draft's *author* was the lock.
Pessimistic, one editor at a time, enforced by ownership rather than
a distinct column. An author could withdraw authorship (the draft
becomes author-less, open for someone else to pick up) or discard
the draft entirely, reverting to head.

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
or absent, and what each combination permits) lives alongside the model
code as the authority for any future work on this lifecycle.

### Translations (Globalize), layered on top

The governing principle for admin views from that rebuild:

*presentation locale* (what language the admin chrome renders in) and
*content-target locale* (which translation a given screen reads or
writes) are separate concerns that must never share a mechanism.

The route's `:locale` segment governs only the former. A locale is
either the default one — edited exclusively through the primary node
editor, pinned via `Globalize.with_locale` regardless of what the route
happens to say, so a stray `/en/` URL can't silently edit the German
content (as has been the case before the rewrite in 2026), or one of
the non-default locales, edited exclusively through a Translations
sub-resource under a deliberately distinct route parameter
(`translation_locale`), chosen specifically because it must never leak
into `default_url_options` the way the chrome locale does. Never both
paths for the same locale.

For now, admin chrome language stays tied to the route locale for now.
A per-editor preference column was considered and set aside as
revisit-later, not built.

Translations carry no independent publish state: a translation goes
live exactly when the draft containing it is promoted to head, same
as everything else in that `Page` row. Both a per-translation
`published_at` and full per-locale draft/head/autosave parity with
`Node` were considered and rejected as unneeded machinery absent a
real editorial need for staggered release timing.

## Events and the calendar

### Problem

Calendar entries required an internal Node — every event
needed a page somewhere in the tree. Editors avoided this: either the
updates stream absorbed non-news content, or a page got created with
no natural place in the navigation. The calendar widget went dormant
rather than get used under those terms.

### Rebuild.

The Event model was rewritten around the RRULE humanizer
(`app/models/concerns/rrule_humanizer.rb`) and a picker UI bound to it
by a deliberate scope rule: the picker only generates or reads back
RRULE shapes the humanizer can also render as prose. A picker that
could express more than the humanizer can describe would let an
editor create a schedule that renders as blank text on the public
page — worse than a raw string the editor had to type by hand.
`Event#node_id` became optional, so an event can point outward (an
external URL) instead of requiring a page. This is what made reviving
the calendar possible at all.

### The problem that surfaced next

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
