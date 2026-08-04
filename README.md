# CCCMS

The content management system behind [www.ccc.de](https://www.ccc.de).

A Rails application with a nested-tree content model, per-node revision
history, translated content via Globalize, and a witnessed action log.
Editing is deliberately open: any editor may draft anywhere, and only
changes that reach the RSS feeds are gated on a role.

## Stack

Ruby 3.4, Rails 8.1, PostgreSQL 16, ImageMagick 7 with Ghostscript.
Production runs on FreeBSD behind nginx with Unicorn; development runs
anywhere the above are available.

## Documentation

- `INSTALL.md` — setting up from scratch, and maintaining an existing
  installation
- `CONTRIBUTING.md` — conventions this codebase follows, and why
- `doc/CUTOVER_2026.md` — historical record of the June 2026 migration
  from Rails 2 to Rails 8. Not maintained.

## Repositories

- https://codeberg.org/erdgeist/cccms
- git://erdgeist.org/cccms

Public content is CC-licensed per page; see the site itself. The code is
beerware. Original code credits to https://github.com/hukl/cccms
