# myERB database migrations

Migrations are numbered SQL files and are intended to be applied in order.

- 001: baseline is represented by `database/init.sql`
- 002: accounting chart, fiscal periods, journal entries and journal lines

For the local Docker environment, `database/init.sql` initializes a fresh PostgreSQL volume. Existing volumes should receive later migrations explicitly before production use.

Production direction:
1. Replace bootstrap SQL with a versioned migration runner.
2. Record applied migrations in a `schema_migrations` table.
3. Never modify an already-applied migration; add a new numbered migration.
4. Run migrations as a release step before starting the API.
