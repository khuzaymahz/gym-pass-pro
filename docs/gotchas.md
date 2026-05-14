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
