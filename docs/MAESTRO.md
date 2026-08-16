# Maestro UI E2E Testing

End-to-end UI tests for the iOS/Android app, driven by
[Maestro](https://maestro.mobile.dev). Flows live in [`.maestro/flows/`](../.maestro/flows/)
and run against the **production backend** (`audiobookphile.vercel.app`), so they
exercise the same auth, library, and playback APIs as real users — including the
magic-link journey (`audiobookphile://` deep link) fixed in the web app.

## Setup

```bash
brew tap mobile-dev-inc/tap && brew install maestro   # once
../audiobookphile-backend/scripts/sync-env.sh         # generates .maestro/.env
```

The env source of truth lives in `audiobookphile-backend/env/local.env`
(see `docs/ENV.md` in that repo).

`.maestro/.env` (gitignored) provides what credential flows need:

| Variable | Used by | Notes |
| --- | --- | --- |
| `SERVER_URL` | all login flows | Web origin that proxies `/api/*` and `/login`. |
| `TEST_EMAIL` / `TEST_PASSWORD` | password login, magic-link request | Account **without 2FA** — the 2FA sheet would divert the login assertion. |
| `MAGIC_LINK_URL` | `12_auth_magic_link_deeplink.yaml` | Fresh single-use deep link; leave empty to skip. |

Build the app for the simulator, then boot one. **The build must be code-signed
(ad-hoc; the default for simulator destinations) — `CODE_SIGNING_ALLOWED=NO`
breaks the login flow**: an unsigned app cannot write to the keychain, so
`saveCredentials` throws `KeychainError.saveFailed` right after the API login
succeeds and the app stays on the connect screen with a "Connection Error"
alert.

```bash
xcodebuild build -workspace Project.xcworkspace -scheme "Audiobookphile App" \
  -destination "platform=iOS Simulator,id=<udid>" -derivedDataPath .build/maestro-dd
```

## Running

```bash
.maestro/run.sh            # smoke + e2e (the CI set)
.maestro/run.sh smoke      # launch-only, no credentials needed
.maestro/run.sh e2e        # login, library, settings
.maestro/run.sh auth       # password login + magic-link request
.maestro/run.sh flows/10_auth_login.yaml   # one flow
.maestro/run.sh --android e2e              # same flows on a connected device
```

The runner installs the newest app build (by modification time, across
`DerivedData` and `.build`) onto every booted simulator before testing, so it
always tests the current build.

## Flow inventory

| Flow | Tags | Verifies |
| --- | --- | --- |
| `00_smoke_launch` | smoke | Cold launch boots the app; when no session exists, the connect sheet renders. |
| `10_auth_login` | auth, e2e | Password sign-in reaches the tab bar / library home. |
| `11_auth_magic_link_request` | auth | Magic-link email request succeeds from the app. |
| `12_auth_magic_link_deeplink` | auth, deeplink | `audiobookphile://` callback URL signs the app in. |
| `20_library_browse` | e2e, browse | Home → Library → Search tab navigation. |
| `30_settings_disconnect` | e2e, settings | Settings sheet opens; Disconnect returns to connect screen. |

`12_auth_magic_link_deeplink` validates the full prod journey of the magic-link
fix: Supabase emails a link → web `/auth/callback` bounces the session via the
custom scheme → the app signs in from the URL parameters. Mint a fresh link
(single-use) from the web app and pass it as `MAGIC_LINK_URL`.

## Conventions

- Shared steps go in subflows prefixed with `_` (e.g. `_login.yaml`); Maestro
  skips them as standalone tests because they carry no tags.
- Prefer stable labels (`accessibilityIdentifier` like `abp_settings_button`,
  `abp_server_url_field`, `abp_email_field`, `abp_password_field`, tab labels,
  button text) over screen points — point taps are last-resort and tuned per
  device. The login fields carry identifiers on the `TextField`/`SecureField`
  in `ConnectView` (`GlassTextField`, `GlassSecureField`).
- **Do not tap text fields by placeholder text.** The keyboard's "Passwords"
  QuickType bar regex-matches `"Password"` and steals the tap; the field never
  gains focus and the typed value lands in the previously focused field. Tap by
  `id` instead, and dismiss the keyboard (`pressKey: Enter`) before focusing
  the password field, which sits under the QuickType bar.
- After sign-in the OS may present the "Save Password?" autofill sheet, which
  blocks the accessibility tree; `_login.yaml` dismisses it via a conditional
  `runFlow` when it appears.
- **Simulator keychain items survive app uninstall.** A session saved by an
  earlier flow auto-signs-in after `clearState` reinstall, so `_login.yaml`
  skips the form when the connect screen is absent, and `00_smoke_launch`
  asserts the connect sheet only when it actually appears.
- **`scrollUntilVisible` is unreliable in sheets**: its 100%-visibility check
  times out for rows clipped by the sheet edge, and a `direction: DOWN` scroll
  drags the sheet into pull-to-dismiss. Flow 30 scrolls with explicit swipes
  and taps directly.
- The Library tab's segmented Library/Authors/Narrators picker exposes only the
  selected segment to the accessibility tree, so flow 20 asserts the tab via
  its exclusive "Filter" toolbar button instead.
- Flows must pass with an **empty** account shelf: assert on the tab bar and
  section headers, not on catalog items.

## CI (`.github/workflows/mobile-e2e.yml`)

Runs on `macos-latest` for pushes to `main` and PRs touching `Sources/`,
`Package.swift`, `.maestro/**`, or the workflow itself. It builds the app for
the newest available iPhone simulator (code-signed — see the build note
above), boots it, resets the simulator keychain (so the first login flow
exercises the connect form), and runs the CI set:

```bash
maestro test .maestro/flows --include-tags smoke,e2e \
  -e SERVER_URL="${SERVER_URL}" -e TEST_EMAIL="${TEST_EMAIL}" \
  -e TEST_PASSWORD="${TEST_PASSWORD}" \
  --format junit --output .maestro-results/
```

Flow env vars are forwarded via `-e` flags: Maestro resolves `${VAR}` only from
CLI flags, not from the process environment.

JUnit results upload as the `maestro-results` artifact (also on failure).

Secrets for the credential flows, stored in repo settings:

| Secret | Purpose | Default |
| --- | --- | --- |
| `MAESTRO_TEST_EMAIL` | Password-login flow account (no 2FA) | — |
| `MAESTRO_TEST_PASSWORD` | Password-login flow account | — |
| `MAESTRO_SERVER_URL` | Web origin proxying `/api/*` and `/login` | `https://audiobookphile.vercel.app` |

The `auth`-only flows (`11_auth_magic_link_request`) and the `deeplink` flow
(`12`) are excluded from CI: the magic-link journey needs a fresh single-use
link minted per run. Run them locally via `.maestro/run.sh auth` after setting
`MAGIC_LINK_URL`; without it, `run.sh` auto-excludes the deeplink flow.
