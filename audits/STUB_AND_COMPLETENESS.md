# Stub & Completeness Audit

## Purpose

Find code that was written aspirationally — frontends calling backends that don't exist, handlers returning hardcoded data, routes that point to missing functions, and UI for features that were never built. The dominant failure mode: a frontend's `.catch(() => fallback)` silently swallows 404s, so phantom endpoints are invisible during manual testing and only surface when someone tries to use the feature.

## When to run

Anytime. Read-only. Especially valuable after a sprint where features were shipped without integration tests, or when an admin/internal panel "looks empty for some reason."

## Time estimate

- **Quick** (30 min): Phase 1 only
- **Standard** (60 min): Phases 1–3
- **Deep** (90+ min): All phases

## Output

Markdown report at `docs/reports/STUB_AUDIT_<YYYY-MM-DD>.md`.

---

## Phase 0: Discovery

Identify the project shape. Record findings for use by later phases.

```bash
# Languages and frameworks
ls package.json go.mod pyproject.toml Cargo.toml Gemfile pom.xml 2>/dev/null
cat package.json 2>/dev/null | head -50
cat go.mod 2>/dev/null | head -10

# Frontend entry points
find . -type f \( -name '*.tsx' -o -name '*.jsx' -o -name '*.vue' -o -name '*.svelte' \) \
  -not -path '*/node_modules/*' -not -path '*/dist/*' | head -20

# Backend route files (heuristic: files that look like routers)
grep -rln --include='*.go' --include='*.py' --include='*.ts' --include='*.js' --include='*.rb' \
  -E '(router|Router)\.(get|post|put|delete|patch)|@(app|router|api|blueprint)\.route|\.HandleFunc|app\.(get|post|put|delete)' \
  . 2>/dev/null | grep -v node_modules | head -20
```

Record: language(s), frontend dir(s), backend service dir(s), router file(s), nginx/gateway config if any.

---

## Phase 1: Frontend → Backend Contract

### 1.1 Extract every URL the frontend calls

```bash
# JS/TS clients
grep -rn --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
  -E "fetch\(|axios\.|XMLHttpRequest|\$\.ajax|api\.(get|post|put|delete|patch)" \
  . 2>/dev/null | grep -v node_modules | grep -v '.compiled.' | grep -v '.min.js'
```

For each match, record: file:line, HTTP method, URL pattern (treat `${var}` as `:var`).

### 1.2 Extract every route the backend registers

Use the framework signature you found in Phase 0. Examples:

```bash
# Go (gin/chi/gorilla/stdlib)
grep -rn --include='*.go' -E '\.(GET|POST|PUT|DELETE|PATCH|HEAD)\(|HandleFunc\(' . | grep -v _test.go

# Python (Flask/FastAPI/Django)
grep -rn --include='*.py' -E '@(app|router|api|blueprint)\.(route|get|post|put|delete|patch)|path\(|url\(' .

# Node (Express/Koa/Hono)
grep -rn --include='*.js' --include='*.ts' -E '(app|router)\.(get|post|put|delete|patch|use)\(' . | grep -v node_modules

# Ruby (Rails)
grep -rn 'resources \|get \|post \|put \|delete ' config/routes.rb 2>/dev/null
```

### 1.3 Cross-reference (scripted)

Extract frontend URLs and backend routes into normalized lists, then diff.

```bash
# 1. Frontend URLs — normalize ${var}/${id} to :param so they compare against backend patterns
grep -rEoh --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
  -E "(fetch|axios\.[a-z]+|api\.(get|post|put|delete|patch))\(\s*['\"\`][^'\"\`]+" . 2>/dev/null \
  | grep -v node_modules | grep -v '\.compiled\.' | grep -v '\.min\.js' \
  | grep -oE "['\"\`]/[^'\"\`]+" \
  | tr -d "'\"\`" \
  | sed -E 's/\$\{[^}]+\}/:param/g; s/\\$\{[^}]+\\}/:param/g' \
  | sed -E 's/\?.*$//' \
  | sort -u > /tmp/frontend_urls.txt
wc -l /tmp/frontend_urls.txt

# 2. Backend routes — extract pattern strings from registrations. One block per framework.
# Go (gin / chi / stdlib)
grep -rEoh --include='*.go' '\.(GET|POST|PUT|DELETE|PATCH)\(\s*"[^"]+"' . 2>/dev/null \
  | grep -v _test.go | grep -oE '"/[^"]+"' | tr -d '"' >> /tmp/backend_urls.raw

# Python (Flask / FastAPI / Django path)
grep -rEoh --include='*.py' \
  -E '(@(app|router|api|blueprint)\.(route|get|post|put|delete|patch)|path|url)\(\s*["'\'']/[^"'\'']+' . 2>/dev/null \
  | grep -oE '["'\'']/[^"'\'']+' | tr -d '"'\''' >> /tmp/backend_urls.raw

# Node (Express / Koa / Hono)
grep -rEoh --include='*.js' --include='*.ts' \
  -E '(app|router)\.(get|post|put|delete|patch|use)\(\s*["'\''`]/[^"'\''`]+' . 2>/dev/null \
  | grep -v node_modules | grep -v test \
  | grep -oE '["'\''`]/[^"'\''`]+' | tr -d '"'\''`' >> /tmp/backend_urls.raw

# Normalize parameter syntax: :id, {id}, <id> → :param
sed -E 's/:[a-zA-Z_][a-zA-Z0-9_]*/:param/g; s/\{[^}]+\}/:param/g; s/<[^>]+>/:param/g' \
  /tmp/backend_urls.raw | sort -u > /tmp/backend_urls.txt
wc -l /tmp/backend_urls.txt

# 3. Account for proxy rewrites that change the URL before it reaches the backend
find . \( -name 'nginx.conf*' -o -name 'nginx.yaml' -o -name 'Caddyfile' \
  -o -path '*/k8s/*ingress*' -o -name 'vercel.json' -o -name 'netlify.toml' \
  -o -name '_redirects' \) 2>/dev/null | grep -v node_modules

# 4. Diff — phantom endpoints (frontend calls, no matching backend route)
echo "=== Phantom endpoints (review for proxy rewrites before reporting) ==="
comm -23 /tmp/frontend_urls.txt /tmp/backend_urls.txt

# 5. Inverse — backend routes the frontend doesn't call (often dead code, sometimes admin/internal)
echo "=== Routes with no frontend caller ==="
comm -13 /tmp/frontend_urls.txt /tmp/backend_urls.txt | head -50
```

URL normalization is imperfect (variable-segment patterns differ between frameworks); review the raw diff manually before reporting findings. Anything in the first list that **isn't** explained by a proxy rewrite is a phantom endpoint.

---

## Phase 2: Stub Handler Hunt

Stubs return hardcoded data instead of querying real sources. They look correct in manual testing but ship empty/wrong data to users. Two complementary heuristics: comment markers (explicit) and response-without-data-access (behavioral).

### 2.1 Comment-marked stubs

```bash
grep -rn -iE '\b(stub|placeholder|not yet|not implemented|TODO|FIXME|HACK|XXX|coming soon)\b' \
  --include='*.go' --include='*.py' --include='*.ts' --include='*.js' --include='*.rb' . \
  | grep -v _test | grep -v node_modules
```

### 2.2 Behavioral stubs (handler files with responses but no data access)

A file with many response calls (`c.JSON`, `jsonify`, `res.json`) but **zero** DB/service calls is almost always a stub. Tested against real codebases; behavioral hits often catch handlers the comment-marker grep misses.

```bash
# Go (gin / stdlib)
for f in $(grep -rln --include='*.go' -E 'gin\.H\{|c\.JSON\(|w\.Write\(' . 2>/dev/null \
            | grep -v _test); do
  total=$(grep -cE 'gin\.H\{|c\.JSON\(|w\.Write\(' "$f")
  data=$(grep -cE 'db\.|store\.|service\.|\.Find\(|\.First\(|\.Where\(|\.Query\(|\.Exec\(' "$f")
  [ "$total" -ge 5 ] && [ "$data" -eq 0 ] && echo "STUB-LIKE: $f  (responses=$total, data_calls=0)"
done

# Python (Flask / FastAPI)
for f in $(grep -rln --include='*.py' -E 'jsonify\(|return\s+(JSONResponse|\{|\[)' . 2>/dev/null \
            | grep -v test | grep -v __pycache__); do
  total=$(grep -cE 'jsonify\(|return\s+(JSONResponse|\{|\[)' "$f")
  data=$(grep -cE '\.query\.|session\.|cursor\.|execute\(|select\(|\.objects\.' "$f")
  [ "$total" -ge 5 ] && [ "$data" -eq 0 ] && echo "STUB-LIKE: $f  (responses=$total, data_calls=0)"
done

# Node (Express / Koa)
for f in $(grep -rln --include='*.js' --include='*.ts' -E 'res\.(json|send)\(' . 2>/dev/null \
            | grep -v node_modules | grep -v test | grep -v '\.d\.ts'); do
  total=$(grep -cE 'res\.(json|send)\(' "$f")
  data=$(grep -cE 'await.*\.(find|findOne|create|update|delete|insert)|prisma\.|knex\(|\.query\(|sequelize' "$f")
  [ "$total" -ge 5 ] && [ "$data" -eq 0 ] && echo "STUB-LIKE: $f  (responses=$total, data_calls=0)"
done
```

The threshold (5+ responses, 0 data calls) tunes for high precision. Lower it (e.g., to `>= 3`) for thoroughness; raise it for noise reduction. A handful of false positives is normal — webhook receivers, healthchecks, and config endpoints legitimately have no DB calls. Verify each hit by reading the file.

### 2.3 Evaluate each stub

For every file flagged by 2.1 or 2.2:

1. Is the feature actually used? (Check Phase 1 frontend URL list.)
2. What would a real implementation look like? Which data source/service?
3. Is the stub response misleading? Returning `{success: true}` for an unimplemented operation is worse than a 501.

---

## Phase 3: Route ↔ Handler Integrity

### 3.1 Defined-but-unregistered handlers

Handlers that exist as functions but have no route pointing to them.

```bash
# Generic: list handler-shaped functions, list functions referenced in route registrations,
# diff the two. Adapt the regex per language.

# Go example
grep -rEhn --include='*.go' '^func \([a-zA-Z]+ \*?[A-Z][a-zA-Z]+\) (handle|Handle)' . \
  | sed -E 's/.*\) (handle[A-Za-z0-9_]+|Handle[A-Za-z0-9_]+).*/\1/' | sort -u > /tmp/defined.txt

# Find which are registered (router file from Phase 0)
grep -hE '\.(handle|Handle)[A-Za-z0-9_]+' <ROUTER_FILE> \
  | grep -oE '(handle|Handle)[A-Za-z0-9_]+' | sort -u > /tmp/registered.txt

comm -23 /tmp/defined.txt /tmp/registered.txt
```

### 3.2 Build/import errors

```bash
# Go
go build ./... 2>&1 | grep -E 'undefined|not declared'
# TS
npx tsc --noEmit 2>&1 | head -50
# Python
python -m py_compile $(find . -name '*.py' -not -path '*/.venv/*' -not -path '*/node_modules/*') 2>&1 | head -50
```

Compile errors in production code = unregistered or broken handlers.

---

## Phase 4: Compiled-Without-Source

Common in JS projects with manually-maintained `.compiled.js` or `dist/` files committed to the repo.

```bash
# Find compiled artifacts that have no matching source
find . -name '*.compiled.js' -not -path '*/node_modules/*' | while read f; do
  src="${f%.compiled.js}.js"; tsx="${f%.compiled.js}.tsx"; ts="${f%.compiled.js}.ts"
  [ ! -f "$src" ] && [ ! -f "$tsx" ] && [ ! -f "$ts" ] && echo "ORPHAN: $f"
done

# Repeat for any /dist/, /build/, /public/js/ that's checked in
```

---

## Phase 5: Dead Features

### 5.1 Unreferenced exports

```bash
# Globals (window.X = ...) defined vs consumed
grep -rEhn --include='*.js' 'window\.[A-Za-z_]+\s*=' . | grep -v node_modules \
  | grep -oE 'window\.[A-Za-z_]+' | sort -u > /tmp/g_defined.txt
grep -rEhn --include='*.js' 'window\.[A-Za-z_]+' . | grep -v node_modules \
  | grep -v '= ' | grep -oE 'window\.[A-Za-z_]+' | sort -u > /tmp/g_used.txt
comm -23 /tmp/g_defined.txt /tmp/g_used.txt
```

### 5.2 Dead services

```bash
# Service-shaped dirs (services/, apps/, packages/) without Dockerfile or deploy manifest
for dir in services/*/ apps/*/ packages/*/ 2>/dev/null; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")
  has_docker=$(find "$dir" -maxdepth 2 -name 'Dockerfile*' | head -1)
  has_deploy=$(find . -path '*/deploy*' -name "*${name}*" 2>/dev/null | head -1)
  [ -z "$has_docker" ] && [ -z "$has_deploy" ] && echo "DEAD?: $dir"
done
```

---

## Severity rubric

| Severity | Criteria |
|----------|----------|
| **P0 — Broken Feature** | User-facing feature fails silently in production |
| **P1 — Hidden Gap** | Admin/internal feature shows empty or wrong data |
| **P2 — Planned Feature** | UI exists for a future feature; stub is intentional but undocumented |
| **P3 — Dead Code** | Endpoint, handler, or UI path that nothing reaches |

---

## Report template

```markdown
# Stub & Completeness Audit — <DATE>

## Summary
- Phantom endpoints: X
- Stub handlers: X
- Unregistered handlers: X
- Compiled-without-source: X
- Dead features: X
- Total findings: X (P0: X, P1: X, P2: X, P3: X)
- Phases run: ...

## P0 — Broken Features
| Frontend call | Backend status | Symptom | Suggested fix |
|---|---|---|---|
| `<file>:<line>` `POST /api/x` | No handler | Form silently no-ops | Implement handler in `<file>` or remove form |

## P1 — Hidden Gaps
...

## P2 — Planned Features
...

## P3 — Dead Code
...

## Patterns observed
<2–3 paragraphs on root causes — e.g., "Frontend was built ahead of backend on the
admin panel; .catch fallbacks made gaps invisible during QA.">

## Recommendations
1. ...
2. ...
```
