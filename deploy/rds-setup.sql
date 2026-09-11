-- Create the three non-primary databases for Solid Cache, Solid Queue and
-- Solid Cable. The primary (givingshelf_prod) is created by the postgres
-- container from POSTGRES_DB on first initialization.
--
-- These names must match config/database.yml exactly (see the cache/queue/cable
-- entries under production). They previously read givingshelf_prod_* here while
-- database.yml expected givingshelf_production_*, which would have failed at
-- cutover.
--
-- `rails db:prepare` also creates these, since the container's POSTGRES_USER is
-- a superuser. This file is the explicit path, preferred during cutover so the
-- databases exist before anything tries to restore into them.
--
-- Usage against the container:
--   docker exec -i givingshelf-db psql -v ON_ERROR_STOP=1 -U gs_user \
--     -d givingshelf_prod -f - < deploy/rds-setup.sql
--
-- Note: CREATE DATABASE cannot run inside a transaction block. psql runs each
-- statement separately by default, so reading the whole file works; if you hit
-- "cannot run inside a transaction block", run each line with its own -c flag.

CREATE DATABASE givingshelf_production_cache;
CREATE DATABASE givingshelf_production_queue;
CREATE DATABASE givingshelf_production_cable;
