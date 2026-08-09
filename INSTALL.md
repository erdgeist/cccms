# Installing CCCMS

A Rails 8 application on PostgreSQL. ImageMagick 7 and Ghostscript are
hard runtime dependencies: image variants, PDF thumbnails and social
cards are shelled out to them. Production runs on FreeBSD behind nginx
with Unicorn; development works anywhere the stack below does.

For the historical record of the June 2026 migration from Rails 2, see
`doc/CUTOVER_2026.md` — it is not an installation guide and is not
maintained.

## 1. Dependencies

| What | Why | FreeBSD 14/15 | Debian/Ubuntu | macOS (brew) |
|---|---|---|---|---|
| PostgreSQL 16 | database | `postgresql16-server postgresql16-client` | `postgresql postgresql-client libpq-dev` | `postgresql@16` |
| ImageMagick **7** | image variants, social cards | `ImageMagick7-nox11` | see trap below | `imagemagick` |
| Ghostscript | PDF rasterisation | `ghostscript10` | `ghostscript` | `ghostscript` |
| libyaml | psych | `libyaml` | `libyaml-dev` | `libyaml` |
| libffi, readline, gdbm | Ruby build | `libffi readline gdbm` | `libffi-dev libreadline-dev libgdbm-dev` | (in base) |
| libxml2, libxslt | libxml-ruby | `libxml2 libxslt` | `libxml2-dev libxslt1-dev` | `libxml2 libxslt` |
| libical | recurrence expansion via the chaos_calendar gem | libical | libical-dev | libical |
| GNU make | native gems | `gmake` | (default) | (default) |
| Node | asset pipeline | `node` | `nodejs` | `node` |
| git, curl, gnupg | fetching and verifying | `git curl gnupg` | `git curl gnupg` | (in base) |

Debian trap: the `imagemagick` package is version 6 on Debian 12 and
earlier, which has no `magick` binary, only the deprecated `convert`.
The code calls `magick` at four sites in
`app/models/concerns/file_attachment.rb`. Check with `magick -version`
before going further; if it is absent, install from a backport or build
ImageMagick 7.

FreeBSD jail: PostgreSQL needs System V shared memory. On the host,
in `/etc/jail.conf`:

    allow.sysvipc = 1;

Restart the jail. Without it PostgreSQL fails to start with a cryptic
shared-memory error.

On 14.x with libical 3.0.20+ the include path for libical is
`<libical/ical.h>`, not `<ical.h>`, should the chaos_calendar Gem act
up.

## 2. Ruby and the gemset

rvm is used for its gemsets, which work like Python venvs. Version
3.4.10.

    curl -L https://github.com/rvm/rvm/releases/download/1.29.12/1.29.12.tar.gz \
      -o /tmp/rvm.tar.gz
    curl -L https://github.com/rvm/rvm/releases/download/1.29.12/1.29.12.tar.gz.asc \
      -o /tmp/rvm.tar.gz.asc
    gpg --keyserver hkps://keys.openpgp.org \
      --recv-keys 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
    gpg --verify /tmp/rvm.tar.gz.asc /tmp/rvm.tar.gz
    tar -xzf /tmp/rvm.tar.gz -C /tmp
    bash /tmp/rvm-1.29.12/install --auto-dotfiles
    source /usr/local/rvm/scripts/rvm

**rvm 1.29.12 is the current stable release and is years old. Its
version list does not know about Ruby 3.4.** Replace it:

    curl -L https://raw.githubusercontent.com/rvm/rvm/master/config/known \
      -o /usr/local/rvm/config/known
    rvm list known | sed -n '/# MRI/,/^$/p'
    rvm install 3.4.10 --autolibs=read-only --with-opt-dir=/usr/local

`--autolibs=read-only` stops rvm running the package manager on your
behalf. `--with-opt-dir=/usr/local` is the libyaml fix: ports and brew
install there, Ruby's configure does not look there, and without it
psych fails to build **silently** and surfaces much later as YAML errors
when Rails loads `database.yml`. Verify the build before continuing:

    ruby -ryaml -ropenssl -rzlib -e 'puts "ok #{Psych::LIBYAML_VERSION}"'

Then the gemset:

    cd /path/to/cccms
    rvm use 3.4.10@rails8-upgrade --create

`.ruby-version` and `.ruby-gemset` in the project root make rvm switch
automatically on entering the directory. `.ruby-version` must keep the
`ruby-` prefix, `ruby-3.4.10`, not `3.4.10`, because the rc.d script
concatenates it into a gemset path and a bare version yields a path that
does not exist.

## 3. Gems

    gem install bundler
    MAKE=gmake bundle install

`MAKE=gmake` on FreeBSD only, and it is not optional: several native
extensions fail against BSD make.

## 4. Database

    # FreeBSD
    sysrc 'postgresql_enable="YES"'
    service postgresql initdb
    service postgresql start

    psql -U postgres postgres

```sql
CREATE ROLE rails WITH LOGIN PASSWORD 'choose-one';
ALTER ROLE rails CREATEDB;

CREATE DATABASE cccms_dev OWNER rails ENCODING 'UTF8'
  LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8' TEMPLATE template0;
```

`CREATEDB` is needed because the test suite creates and drops its own
database. `TEMPLATE template0` is required whenever a non-default locale
is given.

Two config files are gitignored and must be created. `config/database.yml`:

```yaml
development:
  adapter: postgresql
  encoding: unicode
  database: cccms_dev
  pool: 5
  username: rails
  password: choose-one

test:
  adapter: postgresql
  encoding: UTF8
  database: psql_test
  username: rails
  password:
  collation: en_US.UTF-8
  ctype:     en_US.UTF-8
  template:  template0

production:
  adapter: postgresql
  encoding: unicode
  database: cccms_production
  pool: 5
  username: rails
  password: choose-one
```

`config/initializers/secret_token.rb`, one line:

```ruby
Cccms::Application.config.secret_key_base = "<64 hex chars, e.g. from `rails secret`>"
```

### 4a. Load the schema

    bundle exec rails db:schema:load

`db/schema.rb` is in the repository and is the authoritative description
of the database. Replaying the migration chain is not a supported route:
the oldest migrations predate Rails 4, and some columns were only ever
applied by hand. `db:setup` and `db:reset` are safe.

`bundle exec rails db:migrate` is for an existing installation — see the
deploy sequence in §7.

The full-text `search_vector` column is maintained by a PostgreSQL trigger,
which Ruby's schema format cannot express. `db:schema:load` reinstalls it
through a rake hook, and the application reinstalls it at boot, so a fresh
install needs nothing further. A database restored from a dump taken before
the trigger existed has rows it cannot repair, because the trigger fires
only on insert or update. You have to run `pages:backfill_search_vector`
once after such a restore.

## 5. First start

Compile the admin assets. The TinyMCE bundle lives in gitignored
`public/assets/`:

    bundle exec rails assets:precompile

Bootstrap the content tree and one account:

    ADMIN_PASS=choose-one bundle exec rake cccms:init

`ADMIN_LOGIN` (default `admin`) and `ADMIN_EMAIL` are optional. A missing
`ADMIN_PASS` aborts. The task creates root, the Trash, `home`,
`/updates`, `/disclosure`, `/club/erfas`, `/club/chaostreffs` with
placeholder titles, and is idempotent.

Start the server:

    bundle exec rails server -p 3000 -b 0.0.0.0

`-b 0.0.0.0` is required inside a FreeBSD jail, where `localhost` does
not resolve.

`public/system/uploads/` starts empty. It is gitignored; on a fresh
install there is nothing to copy.

### The first admin needs two logins

The bootstrap account is an administrator without a second factor, so
it cannot yet create users, reset factors or deactivate accounts:
administrative actions need a code entered within the last thirty
minutes, and there is no password-only path. This is deliberate. To
finish:

1. sign in as the bootstrap account
2. **Mein Konto** -> enable second factor, scan the QR code, confirm
3. sign out, sign in again, entering the code

Elevation is granted at that login and user management unlocks.

## 6. Production on FreeBSD

Unicorn, started by an rc.d script. Templates in `doc/`:

    doc/unicorn.rb      -> /usr/local/etc/unicorn.rb
    doc/rc.d_cccms      -> /usr/local/etc/rc.d/cccms

The rc.d script reads `.ruby-version` and `.ruby-gemset` from the project
directory to find the gemset — see the prefix note in §2.

nginx proxies everything to Unicorn. Uploads need their own block:

    location /system/uploads/ {
        add_header Content-Security-Policy "sandbox" always;
        add_header X-Content-Type-Options "nosniff" always;

        proxy_pass http://127.0.0.1:9090;
        proxy_set_header Host $host;
        proxy_buffering off;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        proxy_pass http://127.0.0.1:9090/;
        proxy_set_header Host $host;
        proxy_buffering off;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

- Note: No trailing slash on its `proxy_pass`. With one, nginx strips the
  matched prefix and the backend 404s. The `location /` block gets away
  with a trailing slash only because replacing `/` with `/` is a no-op.
- The CSP is not optional. Uploaded files are served by Rails' static
  file server, which bypasses the middleware that sets the application's
  security headers. Without `sandbox`, an uploaded SVG opened directly is
  a document that runs its own script, on the same origin as the site
  and its admin sessions.
- `add_header` in a location replaces inherited headers, so anything
  set at server level must be repeated here.

## 7. Maintenance

### Deploy

    service cccms stop && git pull && bundle exec rails db:migrate && service cccms start

`bundle install` too when `Gemfile.lock` changed. Use `install over`
`update`: the lockfile names exact versions and checksums, so the server
gets what was tested. In development, `touch tmp/restart.txt` restarts a
running server in place.

Occurrences are regenerated yearly at service start. Recurring
events are expanded into finite `occurrences` rows rather than computed
per request. Range queries over 200+ recurring events would otherwise
mean full RRULE expansion on every page load. The window is five years,
which is chaos_calendar's expansion limit.

The rc.d script's `start_postcmd` regenerates when
`/var/db/cccms_occurrences_regenerated` is missing or older than 365
days. Run at post-start, since it must not block the server coming up
or run when startup failed.

    service cccms regenerate_occurrences

The yearly cadence is chosen to coincide with the reboot that follows an
operating-system upgrade. Regeneration is expensive, and that is the
natural point to pay for it.

### Security updates

    gem install bundler-audit      # once, outside the Gemfile
    bundle-audit check --update

Worth running monthly. Vulnerabilities in the HTML sanitizer matter most
here: every page body passes through it.

Ruby upgrades: a new gemset rather than a replacement, so the old one
remains as the way back. Install and populate the new gemset before
pulling a commit that changes `.ruby-version`, or every `rake` and
`runner` invocation breaks while the running server carries on under the
old Ruby.

### One-shot tasks

- `users:clear_otp` is the lockout escape hatch: it clears one account's
  second factor from the shell when every administrator is locked out.
  Deliberately unwitnessed — there is no actor to attribute a shell
  command to.
- `pages:backfill_search_vector` fills `search_vector` for rows that have
  none, and installs the trigger first. Needed after restoring a dump that
  predates the trigger; harmless otherwise, since it only fills nulls.

Logs are in `log/`, gitignored. The action log inside the application at
`/admin/log` records who changed what; `log/production.log` records
everything else.

## 8. Traps

- ImageMagick's policy travels with the project.
  `config/imagemagick/policy.xml` is loaded via `MAGICK_CONFIGURE_PATH`,
  set per invocation. Nothing to install, and do not patch the system
  `policy.xml` or a port upgrade would revert it and a fresh checkout
  would not have it. ImageMagick prepends the project path, so the
  system file is still read.
- Two independent allowlists govern editor HTML. TinyMCE's
  `extended_valid_elements` in `public/javascripts/admin_interface.js`
  and the server's sanitizer in `ContentHelper#aggregate?`. An attribute
  permitted by one and not the other is either offered and discarded, or
  stripped from markup the application itself emits. They must be
  changed together.
- `otp_required` is `false` on every account. Second factors are
  effectively opt-in until that is flipped, and flipping it locks out
  anyone who has not enrolled.
- Uploads are not in the repository. `public/system/` is gitignored
  and is not covered by a database dump either. Back it up separately or
  the site loses every image.
- The test database is not sandboxed against `rails runner`. A `runner`
  invocation that writes will leave rows behind. Wrap writes in a
  transaction with `raise ActiveRecord::Rollback`, or run
  `RAILS_ENV=test bundle exec rails db:test:prepare` afterwards.
- Ruby 3.4 bundled gems are fatal under bundler. A `require` of a
  gem that is bundled-but-not-default warns outside bundler and raises
  `LoadError` under `bundle exec`. `csv` is already declared for this
  reason; the same applies to `base64`, `bigdecimal` and friends if a
  future `require` reaches for one.

## Tests

    bundle exec rake test
