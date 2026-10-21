# InkSlot mobile session proxy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Serve the production API through Netlify same-origin routing so mobile browsers retain the HTTP-only admin session cookie.

**Architecture:** Netlify proxies `/v1/*` to Render while Flutter Web targets the public Netlify `/v1` URL. The backend and secure HTTP-only cookie remain unchanged.

**Tech Stack:** Flutter Web 3.47.5, Dart `--dart-define`, Netlify redirects, NestJS API on Render.

## Global Constraints

- Keep the workspace's three top-level folders: `app`, `api`, and `context`.
- Keep `BrowserClient.withCredentials = true` for Flutter Web.
- Do not move the session token into `localStorage` or expose it to Dart.
- Keep Render as the backend and PostgreSQL provider unchanged.
- Keep `CORS_ALLOWED_ORIGINS` configured with `https://inkslot-app.netlify.app`.
- Do not change public booking routes or the authentication contract.

---

### Task 1: Add the Netlify same-origin API proxy

**Files:**
- Modify: `netlify.toml`

**Interfaces:**
- Consumes: `https://proyect-inkslot.onrender.com/v1`.
- Produces: `https://inkslot-app.netlify.app/v1/*` proxied to Render.

- [ ] **Step 1: Add the proxy rule before the build configuration.**

```toml
[[redirects]]
  from = "/v1/*"
  to = "https://proyect-inkslot.onrender.com/v1/:splat"
  status = 200
  force = true

[build]
  base = "app"
  publish = "build/web"
  command = 'if [ ! -x .flutter/bin/flutter ]; then git clone --depth 1 --branch 3.47.5 https://github.com/flutter/flutter.git .flutter; fi && export PATH="$PWD/.flutter/bin:$PATH" && flutter config --enable-web && flutter pub get && flutter build web --release --dart-define=API_BASE_URL=https://inkslot-app.netlify.app/v1'
```

- [ ] **Step 2: Validate the configuration.**

Run:

```bash
git diff --check
rg -n 'from = "/v1/\*"|to = "https://proyect-inkslot.onrender.com/v1/:splat"|API_BASE_URL=https://inkslot-app.netlify.app/v1' netlify.toml
```

Expected: no diff-check errors and all three values are present.

- [ ] **Step 3: Commit the deployment configuration.**

```bash
git add netlify.toml
git commit -m "fix(deploy): proxy api through netlify origin"
```

### Task 2: Add a regression test for the production same-origin base

**Files:**
- Modify: `app/test/core/network/api_client_test.dart`

**Interfaces:**
- Consumes: `HttpApiClient` and the production same-origin URI.
- Produces: A test that verifies `/v1` joins correctly with `/auth/me`.

- [ ] **Step 1: Add this test after the query-parameter test.**

```dart
  test('joins protected production paths through the Netlify same origin', () async {
    final client = RecordingHttpClient((request) async {
      expect(
        request.url,
        Uri.parse('https://inkslot-app.netlify.app/v1/auth/me'),
      );
      return http.Response('{"user":{"id":"artist-1"}}', 200);
    });
    final api = HttpApiClient(
      client: client,
      baseUri: Uri.parse('https://inkslot-app.netlify.app/v1'),
    );

    expect(await api.getJson('/auth/me'), {
      'user': {'id': 'artist-1'},
    });
  });
```

- [ ] **Step 2: Run the focused test from `app`.**

```bash
fvm flutter test test/core/network/api_client_test.dart
```

Expected: all tests in the file pass.

- [ ] **Step 3: Commit the regression test.**

```bash
git add app/test/core/network/api_client_test.dart
git commit -m "test(network): cover production same-origin api base"
```

### Task 3: Build and verify the deployable web artifact

**Files:**
- Verify: `netlify.toml`
- Verify: `app/build/web/`

**Interfaces:**
- Consumes: the Netlify build command and the API base regression test.
- Produces: a Flutter Web release artifact configured for the proxy.

- [ ] **Step 1: Run the analyzer from `app`.**

```bash
fvm flutter analyze
```

Expected: no analyzer issues.

- [ ] **Step 2: Build the production web artifact from `app`.**

```bash
fvm flutter build web --release --dart-define=API_BASE_URL=https://inkslot-app.netlify.app/v1
```

Expected: exit code 0 and output in `app/build/web`.

- [ ] **Step 3: Verify the working tree from the workspace root.**

```bash
git diff --check
git status --short
```

Expected: no diff-check errors and no uncommitted source changes.

### Task 4: Verify production after Netlify deploy

**Files:**
- Verify externally: `https://inkslot-app.netlify.app/v1/health`

**Interfaces:**
- Consumes: the deployed Netlify proxy and Render health endpoint.
- Produces: evidence that same-origin routing reaches Render.

- [ ] **Step 1: Verify the health route through Netlify.**

```bash
curl -i --max-time 20 https://inkslot-app.netlify.app/v1/health
```

Expected: a successful API response, not a Netlify 404.

- [ ] **Step 2: Test the admin session on mobile.**

Open `https://inkslot-app.netlify.app/#/admin/login`, log in, open the dashboard, refresh the page, and navigate to Agenda. Expected: the session remains active in Safari and Chrome mobile.

- [ ] **Step 3: Confirm the web build no longer calls Render directly.**

Expected network requests from Flutter Web use `https://inkslot-app.netlify.app/v1/...` and do not use `https://proyect-inkslot.onrender.com/v1` directly.

