# Contributing to CCCMS

## Stack
Rails 8.1, Ruby 3.2, PostgreSQL 16, ImageMagick 7 (`magick`, not `convert`).
No Sprockets pipeline for public or admin static assets except
`admin_bundle.js` — everything else is served straight from `public/` and
cache-busted via file mtime (`ApplicationHelper#mtime_busted_path`), not
fingerprinted content hashing.

## Content model
- **Node** — the tree structure (`awesome_nested_set`-derived, migrating
  toward a plain `parent_id` model — both may be present during that
  transition). Holds three separate Page references: `head` (published),
  `draft` (being worked on), `autosave` (in-progress typing).
- **Page** — one revision's content. `belongs_to :node`, except `autosave`
  layers specifically: their `node_id` is deliberately `nil`, which is what
  keeps them out of `node.pages` (the real revision history) entirely —
  an autosave is not a revision.
- **Page::Translation** — Globalize's own generated class (`translates
  :title, :abstract, :body` on `Page`). Not a top-level `PageTranslation`
  constant, and it has `page_id`, not a `page` association reader.

## Publishing lifecycle
There is exactly one path from an edit to a published change:
`autosave!` (writes into the autosave layer, creating it via
`clone_attributes_from` on the previous head/draft if it doesn't exist yet)
→ `save_draft!` (clones the *entire* autosave into the draft layer,
wholesale — every locale, not just the one just edited) → `publish_draft!`
(promotes draft to head). Nothing writes to `draft` or `head` directly.
Locking (`lock_for_editing!`, raising `LockedByAnotherUser`) gates every
step; a lock can exist with no draft or autosave at all (acquisition is
deliberately separate from content creation).

## Locale architecture
Presentation locale (which language the admin chrome or public page
renders in) and content-target locale (which translation a given screen is
reading or writing) are two different concerns and never share a
mechanism. The route's `:locale` segment governs the former only. The
primary node editor always targets the default locale, enforced via
`Globalize.with_locale` (never `I18n.locale`, which would leak into
generated URLs through `default_url_options`). Non-default-locale editing
uses a separately-named route param (`:translation_locale`), deliberately
distinct from `:locale` so the two can never be conflated by a link helper.
Globalize's configured fallback chain is correct for public rendering and
wrong for editing — anywhere a screen needs to know a translation's real,
unborrowed state, read the `Page::Translation` row directly rather than the
locale-dependent attribute accessor.

## Assets
`FileAttachment` (`app/models/concerns/file_attachment.rb`) is a from-
scratch Paperclip replacement. `STYLES` is a hash of style name to a full
ImageMagick argument array (not just a geometry string — some styles need
`-gravity`/`-extent` alongside `-resize`, which a single string can't
express). `generate_variants` loops over `STYLES` generically; adding a
style needs no other code change, only `bundle exec rake
assets:regenerate_variants` to backfill existing assets. The URL contract
(`/system/uploads/:id/:style/:filename`) is stable and safe to parse
directly (the numeric id is always the second path segment) rather than
reconstructed through model methods.

## Aggregator / shortcode system
`[aggregate ...]` in page body text is parsed by
`ContentHelper#aggregate?` into an options hash, then executed by
`Page.aggregate`. Only `tags`, `children` (`"direct"`/`"all"`, combined
with the current node), `order_by`/`order_direction`, and `limit` are
actually consumed.  Only the first `[aggregate ...]` in a given body is
ever processed (`aggregate?` does a single, non-global match).

## TinyMCE integration
`extended_valid_elements` must define a parent element and its commonly-
nested children symmetrically and explicitly together — leaving one
element on the schema's default rule while the other is explicitly
redefined can cause content loss on save, even when the child would be
perfectly valid under the untouched default alone. `valid_classes` denies
all classes by default (`'*': ''`); anything meant to render needs an
explicit per-element allowance. `content_style` injects CSS into the
editing iframe directly — the app's real public stylesheet is never loaded
there, so anything that needs to render correctly while editing needs its
own rule supplied this way. Constrained-input features (fixed placement
choices, for instance) are built as custom toolbar buttons with their own
dialog and `editor.insertContent()`, not the native image dialog or
`file_picker_callback` — those bring their own resize/edit affordances that
would undermine a genuinely fixed set of choices.

## Testing
Shared test-only convenience methods (that need to operate across many
model/controller test files) live directly on `ActiveSupport::TestCase`,
in `test/test_helper.rb` — the framework's own designated extension point
for exactly this, not a monkey-patch of a production model class.
