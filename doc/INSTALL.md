# CCCMS Installation Guide

This document covers the non-obvious steps required to install the CCCMS
stack on a fresh FreeBSD jail. It assumes a FreeBSD 14.x base jail with
network access and a working pkg repository.

## 1. Install packages

```sh
pkg install gmake pkgconf curl gnupg git autoconf automake libtool bash \
  readline libyaml libffi gdbm libxml2 libxslt libical \
  postgresql16-server postgresql16-client \
  ImageMagick7-nox11 node vim
```

Note: the package is `ImageMagick7-nox11`, not `ImageMagick-nox11`. The
nox11 variant avoids pulling in the entire X11 dependency chain.

## 2. Enable sysvipc for the jail

PostgreSQL uses System V shared memory for inter-process communication.
On the host, the jail must have sysvipc enabled. In `/etc/jail.conf` or
the jail's ezjail configuration:

  `allow.sysvipc = 1;`

Restart the jail after making this change. Without it, PostgreSQL will
fail to start with a shared memory error.

## 3. Enable and initialise PostgreSQL

```sh
# Enable PostgreSQL in rc.conf
echo 'postgresql_enable="YES"' >> /etc/rc.conf

# Initialise the database cluster
service postgresql initdb

# Start PostgreSQL
service postgresql start
```

## 4. Create database roles and set permissions

```sh
psql -U postgres postgres
```

```sql
CREATE ROLE rails WITH LOGIN PASSWORD 'your-password-here';
ALTER ROLE rails CREATEDB;
```

`CREATEDB` is required for the Rails test suite to create and drop the
test database between runs.

## 5. Create databases

```sql
CREATE DATABASE cccms_production OWNER rails ENCODING 'UTF8'
  LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8' TEMPLATE template0;
CREATE DATABASE cccms_dev OWNER rails ENCODING 'UTF8'
  LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8' TEMPLATE template0;
CREATE DATABASE psql_test OWNER rails ENCODING 'UTF8'
  LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8' TEMPLATE template0;
```

`TEMPLATE template0` is required when specifying a non-default locale.

## 6. Restore the database dump (or start empty)

If restoring from a pg_dump:

```sh
pg_restore -U postgres -d cccms_production \
  --no-owner --no-acl /path/to/cccms_production.dump

pg_restore -U postgres -d cccms_dev \
  --no-owner --no-acl /path/to/cccms_production.dump
```

Expected harmless warnings:
- `schema "public" already exists` — benign, ignore
- `array_accum aggregate` failure — dead code, ignore

Transfer ownership to the rails user (REASSIGN OWNED does not work on
PostgreSQL 15+ due to system object protection):

```sh
psql -U postgres cccms_production
```

```sql
DO $$
DECLARE
  obj RECORD;
BEGIN
  FOR obj IN
    SELECT tablename FROM pg_tables WHERE schemaname = 'public'
  LOOP
    EXECUTE 'ALTER TABLE public.' || quote_ident(obj.tablename) ||
            ' OWNER TO rails';
  END LOOP;
  FOR obj IN
    SELECT sequence_name FROM information_schema.sequences
    WHERE sequence_schema = 'public'
  LOOP
    EXECUTE 'ALTER SEQUENCE public.' || quote_ident(obj.sequence_name) ||
            ' OWNER TO rails';
  END LOOP;
  FOR obj IN
    SELECT viewname FROM pg_views WHERE schemaname = 'public'
  LOOP
    EXECUTE 'ALTER VIEW public.' || quote_ident(obj.viewname) ||
            ' OWNER TO rails';
  END LOOP;
END $$;

ALTER SCHEMA public OWNER TO rails;
```

Repeat for `cccms_dev`.

## 7. Clone the repository

```sh
cd /usr/local/www
git clone https://github.com/erdgeist/cccms.git
cd cccms
git checkout rails-upgrade
```

## 8. Copy assets (optional but recommended)

The `public/system/uploads/` directory contains all uploaded files
referenced by the database. Without it, images and attachments will be
missing throughout the site.

```sh
# On the source system:
tar -czf /tmp/cccms_uploads.tar.gz -C /usr/local/www cccms/public/system

# On the new system:
tar -xzf /path/to/cccms_uploads.tar.gz -C /usr/local/www
```

## 9. Copy gitignored config files

These files are not in the repository and must be copied or created:

```sh
# Required:
config/database.yml
config/initializers/secret_token.rb

# If used:
config/initializers/exception_notification.rb
/usr/local/etc/unicorn.rb
```

`database.yml` template:

```yaml
development:
  adapter: postgresql
  encoding: unicode
  database: cccms_dev
  pool: 5
  username: rails
  password: your-password-here

test:
  adapter: postgresql
  encoding: UTF8
  database: psql_test
  username: rails
  password:

production:
  adapter: postgresql
  encoding: unicode
  database: cccms_production
  pool: 5
  username: rails
  password: your-password-here
```

## 10. Install rvm

rvm 1.29.12 is the latest formal release as of mid-2026. Download and
verify before installing:

```sh
curl -L https://github.com/rvm/rvm/releases/download/1.29.12/1.29.12.tar.gz \
  -o /tmp/rvm-1.29.12.tar.gz
curl -L https://github.com/rvm/rvm/releases/download/1.29.12/1.29.12.tar.gz.asc \
  -o /tmp/rvm-1.29.12.tar.gz.asc

gpg --keyserver hkps://keys.openpgp.org \
  --recv-keys 7D2BAF1CF37B13E2069D6956105BD0E739499BDB

gpg --verify /tmp/rvm-1.29.12.tar.gz.asc /tmp/rvm-1.29.12.tar.gz
```

If verification passes:

```sh
tar -xzf /tmp/rvm-1.29.12.tar.gz -C /tmp
bash /tmp/rvm-1.29.12/install --auto-dotfiles
source /usr/local/rvm/scripts/rvm
```

The installed rvm ships with a stale known-versions list that only goes
to Ruby 3.0.0. Update it immediately:

```sh
curl -L https://raw.githubusercontent.com/rvm/rvm/master/config/known \
  -o /usr/local/rvm/config/known
rvm list known | grep '^\[ruby-\]3\.'
```

Should now show Ruby 3.2.x and later.

## 11. Install Ruby and create gemset

```sh
source /usr/local/rvm/scripts/rvm
rvm install 3.2.11 --autolibs=read-only --with-opt-dir=/usr/local
rvm use 3.2.11
rvm gemset create rails7-upgrade
rvm use 3.2.11@rails7-upgrade
```

The `.ruby-version` and `.ruby-gemset` files in the project root will
cause rvm to switch automatically when entering the project directory.

## 12. Install bundler and gems

```sh
gem install bundler
cd /usr/local/www/cccms
export MAKE=gmake
bundle install 2>&1 | tee /tmp/bundle_install.log
```

`MAKE=gmake` is required because FreeBSD's native make (BSD make) uses
different `-j` syntax than native gems expect. Without it, several native
gem compilations will fail.

## 13. Run migrations

```sh
bundle exec rails db:migrate
```

If restoring an existing database, first insert fake migration versions
to prevent re-running migrations that were applied to the old schema:

```sql
INSERT INTO schema_migrations (version) VALUES
  ('20260624035149'), ('20260624035150'), ('20260624035151'),
  ('20260624035152'), ('20260624035153'),
  ('20260625031409')
ON CONFLICT DO NOTHING;
```

Then run `db:migrate` to apply only new migrations.

To enable full-text search (requires PostgreSQL 10+ with plpgsql):

```sh
mv doc/20260626025705_add_search_vector_to_page_translations.rb.pending \
   db/migrate/20260626025705_add_search_vector_to_page_translations.rb
bundle exec rails db:migrate
```

## 14. Compile admin assets

```sh
bundle exec rails assets:precompile
```

This compiles the admin JavaScript bundle (jQuery, jQuery UI, hotkeys)
into `public/assets/`. Required for the admin interface to work. Must be
re-run after any changes to `app/assets/javascripts/admin_bundle.js`.

## 15. Run tests (optional but recommended)

```sh
bundle exec rake test
```

Expected result: 129 runs, ~339 assertions, 3 failures, 0 errors.
The 3 failures are pre-existing and documented in the handover document.

## 16. Start the server

Development:

```sh
bundle exec rails server -p 3000 -b 0.0.0.0 -e development
```

Note: `-b 0.0.0.0` is required — `localhost` does not resolve inside
a FreeBSD jail.

Production (unicorn):

```sh
/usr/local/rvm/gems/ruby-3.2.11@rails7-upgrade/wrappers/unicorn \
  -c /usr/local/etc/unicorn.rb -E production -D
```

The rc.d script at `/etc/rc.d/cccms` needs updating from `unicorn_rails`
to `unicorn` before use — see the handover document for details.

## Known Gotchas

**sysvipc:** PostgreSQL will fail silently or with a cryptic error if
sysvipc is not enabled for the jail. Enable it on the host before starting
PostgreSQL.

**MAKE=gmake:** Native gem compilation fails without this. Set it before
every `bundle install` or add to your shell profile.

**rvm known versions:** rvm 1.29.12 ships with a stale `config/known` that
only lists Ruby up to 3.0.0. Always update from master after installing rvm.

**ImageMagick 7:** The `convert` command is deprecated; use `magick convert`.
The `file_attachment.rb` concern needs updating before production use.

**pg_hba.conf:** The default FreeBSD PostgreSQL configuration uses `trust`
for local Unix socket connections, which is sufficient for the application.
No changes needed unless TCP connections are required.

**assets:precompile:** Must be run after checkout and after any changes to
admin JavaScript. The compiled files in `public/assets/` are gitignored.

**chaos_calendar include path:** On FreeBSD 14.x with libical 3.0.20+,
the include path is `<libical/ical.h>` not `<ical.h>`. This is already
fixed in the `erdgeist-ruby1.9` branch.
