# Database Deployment State

**CRITICAL WARNING:** Do NOT run `supabase db push` blindly.

## Current Migration Status

The live production Supabase database state is **divergent** from the clean, tracked local migration history due to necessary out-of-band hotfixes and state rescues. 

Specifically:
- **Migrations 015–021** were manually applied directly to the live database in previous sessions to recover from a corrupted migration state.
- **Migrations 022–028** (which include the display-name immutability, signup triggers, and security definer functions) have also been manually applied to the live database.

Because these migrations were executed manually via the SQL Editor, the internal `supabase_migrations.schema_migrations` tracking table on the remote database does not accurately reflect the sequential hashes of the local files.

## Future Protocol

Because the local migration history is no longer safely synchronized with the remote migration ledger:
1. **Never use `supabase db push`** without explicitly verifying the migration ledger state. Running it blindly will likely cause duplicate execution errors or destructive failures.
2. **Future database changes** require deliberate, manual migration and deployment handling (e.g., executing the SQL directly or repairing the remote ledger hashes).
3. If new migrations are created (e.g. `029_...`), they must be executed manually on the live remote database, or the remote `schema_migrations` table must be carefully manually repaired to match the local project state before relying on Supabase CLI commands.
