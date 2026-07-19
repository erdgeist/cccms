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
