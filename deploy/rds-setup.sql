-- Create additional databases for Rails Solid Cache, Solid Queue, and Solid Cable.
-- Run this after RDS creates the primary database (givingshelf_prod).
--
-- Option 1: Run entire file (psql executes each statement separately)
--   PGPASSWORD='xxx' psql -h RDS_ENDPOINT -U gs_admin -d givingshelf_prod -f deploy/rds-setup.sql
--
-- Option 2: If you get "CREATE DATABASE cannot run inside a transaction block",
--   run each CREATE separately with: psql ... -c "CREATE DATABASE givingshelf_production_cache;"
--   etc.

CREATE DATABASE givingshelf_prod_cache;
CREATE DATABASE givingshelf_prod_queue;
CREATE DATABASE givingshelf_prod_cable;
