Week 4:

Challenge 4 of 8: The Migration That Passed Staging

Scenario. From the first of next month, finance will invoice in EUR and IDR. An engineer asked an AI for the database migration below. The AI answered: "Tested on staging: ran in 1.8 s, no errors. Zero downtime. Fully reversible: down() restores the previous state. Safe to run during business hours." The runner calls up() automatically at the start of the deploy, before the new app version rolls out.

1 exports.up = async (db) => {
2 await db.query("ALTER TABLE invoices ADD COLUMN currency text NOT NULL DEFAULT 'USD'");
3 await db.query(`UPDATE invoices SET currency =
 4      CASE country WHEN 'DE' THEN 'EUR' WHEN 'ID' THEN 'IDR' ELSE 'USD' END`);
5 await db.query('CREATE INDEX invoices_currency_idx ON invoices (currency, created_at)');
6 await db.query('ALTER TABLE invoices RENAME COLUMN amount TO total_amount');
7 await db.query('ALTER TABLE invoices ADD CONSTRAINT amount_nonneg CHECK (total_amount >= 0)');
8 };
9
10 exports.down = async (db) => {
11 await db.query('ALTER TABLE invoices DROP COLUMN currency');
12 await db.query('ALTER TABLE invoices RENAME COLUMN total_amount TO amount');
13 };
Production facts. invoices has about 120M rows (roughly 180 GB with its indexes). It takes about 800 inserts per second at peak, and it is read all day by the app and by dashboards on a read replica. Six app pods run behind a rolling deploy: new pods start after the migration, and old pods keep serving until each one is replaced (about 5 minutes in total). Staging has about 500k rows, no traffic and one pod. Finance invoices customers around the clock, so the business expects no visible downtime.

The trap. A migration is judged by what it does to the traffic and the code that are already there, not by how fast it runs on an empty system. "It ran fine on staging" describes a different database from the one you will migrate.

Constraints. You cannot run anything on production, and no production data may leave it. You have a local Postgres and the staging database. No paid tools. Node stays. Avoid new dependencies (justify any). Use placeholders instead of real data or credentials. The change must ship in this release.

Questions
• Which claims in the AI's answer do you refuse to accept, and what would trustworthy evidence look like?
• Write the follow-up prompt that gets a plan that survives production, and that rejects "it ran fine on staging" as proof.
• How do you prove it is safe without touching production, and what is your Plan B if the migration is already running and the app starts to hang, or if the AI's next version is still unsafe?

Answer format: 1) Verdict · 2) Issues found (line numbers) · 3) Follow-up prompt · 4) Evidence required (raw output, who ran it and on what data, or NOT RUN) · 5) Verification plan including Plan B · 6) Confidence · 7) What I accepted, changed or rejected from the AI
