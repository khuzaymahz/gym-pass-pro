# Framework gotchas

A short log of framework / library traps that **already cost us
debugging time on this codebase**. Each entry is here because it
happened — not because it might happen. Keep entries small (≤ 5
lines of body each) so the list stays scannable.

Adding a new entry: include the **symptom** (what looked wrong),
the **cause** (what the framework was actually doing), and the
**fix shape** (one-liner pointer to how we resolved it). Cite the
commit or file path if helpful.

---

## SQLAlchemy AsyncSession is not safe for concurrent queries

**Symptom**: an obvious "let me just `asyncio.gather` these
independent reads" feels like the right speed-up.

**Cause**: `AsyncSession` serialises operations on its underlying
connection. `gather`-ing queries on a single session either raises
`InvalidRequestError` or silently queues them — so no parallelism
is achieved and the apparent speedup is a mirage.

**Fix shape**: each gather task opens its own session from
`session_factory()`. See `backend/app/services/partner_metrics_service.py::_q`
and `backend/app/db/session.py::session_factory`.

---

## Next.js Server Action IDs rotate in dev after `revalidatePath`

**Symptom**: clicking Save / Upload / any form on the page 404s
with `Failed to find Server Action <hash>`. Usually after a
container restart or after toggling locale.

**Cause**: Server Action hashes are baked into the rendered HTML
the browser holds. Anything that triggers a chunk rebuild
(`revalidatePath`, container restart, hot-reload of an action
file) rotates the hashes. The browser DOM still POSTs the old
ones.

**Fix shape**: avoid `revalidatePath('/', 'layout')` for user-
preference flips (locale, theme) — set cookies client-side and
`router.refresh()` instead. For after-deploy 404s, hard-refresh
the tab. See `gym-partner/src/components/LocaleToggle.tsx`.

---

## Next.js "use client" boundary doesn't forward non-function exports

**Symptom**: `PERIOD_PRESETS.includes is not a function` (or
similar) when a server component imports a constant or type from
a `"use client"` module. The page works on first build, errors at
runtime.

**Cause**: Next.js only special-cases **component** exports across
the client boundary. Other exports (arrays, constants, types)
resolve to opaque proxy references in the server runtime.

**Fix shape**: move shared values to a plain (non-`"use client"`)
module like `lib/period.ts`. Both the client component and the
server page import from there. See `gym-partner/src/lib/period.ts`.

---

## React `useState` initializer runs on both server and client → hydration mismatch

**Symptom**: dev overlay shows "Hydration failed because the server
rendered text didn't match the client" pointing at a `useState`-
backed component.

**Cause**: the `useState(() => …)` initializer runs **once on the
server** (during SSR) and **once on the client** (during hydration).
If the initializer reads `window`, `matchMedia`, or `Date.now()`,
the two runs produce different values and React refuses to hydrate
that subtree.

**Fix shape**: initial state must be **stable across server +
client first render**. Move client-only branches (animation start
from 0, reduced-motion checks) into a `useEffect` that runs
post-mount. See `gym-partner/src/components/CountUp.tsx`.


---

## Historical migrations 0014 + 0018 — known risks at scale

Two past migrations have known sharp edges that we can't fix in-place
(CLAUDE.md §12 #8 forbids editing past migrations), so flagging here
for anyone replaying them against a large prod DB:

**0014_partner_hot_path_indexes**: creates indexes on `checkins`
WITHOUT `CREATE INDEX CONCURRENTLY`. On a non-empty checkins table
this acquires `ACCESS EXCLUSIVE` for the duration and every scan in
flight 500s. Pre-prod ran clean because the table was nearly empty
at upgrade time. Before the first real-prod replay, drop the
indexes manually with `DROP INDEX CONCURRENTLY`, then re-create
them online with `CREATE INDEX CONCURRENTLY` before the alembic
step — or run alembic with the indexes already in place so
alembic's `CREATE` becomes a `IF NOT EXISTS` no-op.

**0018_audit_log_partitioned**: backfills the new partitioned
`audit_log` from `audit_log_pre_partition` in a single transaction
via `INSERT ... SELECT *`. With millions of pre-existing audit rows
this OOMs the migrator container. Before replaying, chunk the
backfill manually in 50k-row batches gated by `created_at` range,
then run the migration which finds the data already moved.

**Fix shape**: both are operator runbook items, not code edits.
Add a flagged paragraph to `docs/deploy.md` when the first big
prod cutover is scheduled.
