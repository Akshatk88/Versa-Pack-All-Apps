# Phase 0 — Analysis Report

Per MASTER_PROMPT.md §6 / §14. **No production code has been written.**

---

## 0. Headline

**Gate 0 passes — the backend is present, complete, and readable.** §4.1's warning
that `backend/` was empty is out of date; the full Express/Mongo source is at
`backend/quick-commerce/`. I mapped it end to end (see `API_MAP.md`).

**But a larger premise in the document does not hold, and it changes the plan.**

MASTER_PROMPT.md §2 is titled *"THE EXISTING SYSTEM — WHAT YOU MUST REUSE"* and
describes a reference Flutter app — Dart package `food_user_application`, 21
features, a Dio client with a refresh-token queue, `AppToast`, `AppRefreshIndicator`,
`TokenStorage`, `AppColors`, 8 core services, a `StatefulShellRoute` router.

**None of it exists in this repository.**

| §2 claim | Reality |
|---|---|
| Package `food_user_application` | Package is `quick_commerce_seller` (`pubspec.yaml:1`) |
| App version `4.1.1+1` | `1.0.0+1` |
| 21 features under `lib/features/` | `lib/` contains **one file**: `main.dart`, the unmodified Flutter counter demo |
| 20+ deps: riverpod, go_router, dio, secure_storage, firebase, socket_io, image_picker, maps… | `pubspec.yaml` has **`cupertino_icons` and `flutter_lints`**. Nothing else |
| `lib/core/network/dio_client.dart`, `AppToast`, `TokenStorage`, `xFileToMultipart`, `AppColors`, `resetSessionScopedProviders`, `fcm_service.dart`, `socket_service.dart` | None exist |
| Android `applicationId com.appzetofood.restaurant` | `com.example.quick_commerce_seller` |
| `test/` does not exist | `test/widget_test.dart` exists (the default counter test — and it will fail once `main.dart` changes) |

§2.4 also says `GUIDELINES.md` diverges from "the real code" and that the real
code is feature-first. There is no real code to diverge from; both structures are
currently hypothetical.

**Consequence:** every rule of the form *"reuse X, do not re-create it"* — §2.5
through §2.15, R2, and the entire "Reuse" block of the §11 checklist — has no
referent. This is not a licence to improvise: the *patterns* §2 documents are
detailed and coherent, and I will build to them exactly. But **M0 is not
"confirm and adjust the shell." M0 is "build the entire foundation from
nothing"** — bootstrap, Dio client with the refresh queue, token storage, theme,
router, shared widgets, and the eight core services — and it is roughly an
order of magnitude larger than §7/M0 implies.

§0 says: *"If a rule in this document turns out to be impossible or wrong given
what you find in the repository, stop and report it. Do not silently deviate."*
That is what this report does. **Question Q1 below is blocking.**

---

## 1. Architecture summary (as it will be built)

There is nothing to summarise from existing code, so this is my reading of the
target §2 specifies, in my own words:

- **Layers.** Feature-first: `lib/features/<f>/{data,domain,presentation}`. Domain
  is plain Dart — no Flutter, Riverpod, or Dio import. Data implements the API
  calls and returns domain models. Presentation holds controllers and widgets.
  Cross-cutting infrastructure sits in `lib/core/`, configuration in `lib/config/`.
- **DI graph.** One `dioProvider` at the root. Each feature's
  `xRepositoryProvider` is a plain `Provider` reading `dioProvider`. Each screen's
  `xControllerProvider` is an `AsyncNotifierProvider` reading its repository.
  Nothing is constructed outside a provider.
- **Navigation.** `goRouterProvider` with a redirect driven by a listener on
  `authControllerProvider`, refreshed via `notifyListeners()` rather than by
  rebuilding the router (rebuilding resets the nav stack). Public route set,
  `StatefulShellRoute.indexedStack` for the bottom tabs, a public
  `rootNavigatorKey` so FCM tap handling can navigate without a `BuildContext`.
- **Auth flow.** OTP request → verify → either `needsRegistration` (multi-step
  registration) or tokens. Tokens in `flutter_secure_storage`. A 401 on a
  non-auth endpoint triggers a single de-duplicated refresh through a `Completer`
  queue, then replays the original request; a failed refresh clears storage and
  fires session-expired, which the router turns into `/login`.
- **Error flow.** The Dio interceptor is the only place raw transport errors
  exist. Everything leaving it is a `DioException` wrapping an `ApiException`
  carrying the server's `message`. Repositories let it propagate; controllers
  catch it with `AsyncValue.guard`; the UI renders `ApiException.message`.

## 2. Reusable-asset inventory

**Empty.** Nothing in `lib/` is reusable — it is the counter demo. There are no
existing widgets, services, utils, providers, or theme tokens to reuse, and
therefore no duplication risk in M0. Every item in §2.12 and §2.13 must be
authored as part of the foundation.

`test/widget_test.dart` (the default counter test) will break the moment
`main.dart` changes and should be replaced in M0.

## 3. Backend inventory

Full detail is in `API_MAP.md`. Summary:

- **The seller is the `RESTAURANT` role.** Quick commerce was built as a
  conversion of an existing food-delivery backend rather than a new module
  (`QUICK_COMMERCE_CHANGES.md`), so the seller's entire surface lives under
  `/api/v1/food/restaurant`. Terminology per §5.7: the backend says *restaurant*,
  *food*, *menu*, *addon* where the seller app will say *store*, *product*,
  *catalogue*. **Backend vocabulary governs model and field names; UI copy uses
  the seller-app words.**
- **Envelope matches** what §2.5 describes: `{ success, message, data }`
  (`utils/response.js:1`), errors `{ success:false, message }`. The planned
  interceptor design is correct — with the caveat that `data` can be absent
  (D7 in `API_MAP.md`), so the unwrap must tolerate null.
- **Auth is OTP-only** for sellers; no password path exists. Access token 15m,
  refresh 7d.
- **Single-device eviction.** Every login increments `tokenVersion`; a stale
  token 401s with *"You have been signed out because this account was used on
  another device."* Crucially the refresh token is stale too, so **this 401 is
  permanent, not transient** — the refresh interceptor must not treat it as a
  retryable expiry or it will loop. This is the single most important backend
  behaviour for M0.
- **Route groups:** auth · onboarding/profile/store · media/banners · categories
  · foods/menu/addons · stock · orders · finance/withdrawals/subscription ·
  offers · support/complaints · notifications · FCM · chat · uploads.
- **Uploads:** multipart. Two paths with **different limits** — `/v1/uploads/image`
  (5 MB, MIME-filtered, unauthenticated) and the restaurant-module routes
  (25 MB, no MIME filter). Returned `url` is usually **relative**; the app must
  prefix it with the API origin.
- **Realtime:** Socket.IO, default path/namespace, handshake `auth: { token }`,
  room `restaurant:<id>` auto-joined. `new_order` and `order_status_update` are
  the events that matter. `order_status_update` is emitted from five places with
  five different field sets — parse defensively, always reconcile with a REST
  refetch.
- **Push:** new-order pushes require the Android channel id **`new_order_channel`**
  verbatim, or Android silently demotes them. Sent as a data-only + notification
  pair so Accept/Reject action buttons survive.
- **Pagination is inconsistent** — four envelope shapes and four list keys across
  seller endpoints. A single shared paging model will silently return empty
  lists on half of them; parse per endpoint.

## 4. `API_MAP.md`

Written at the repository root. Backend columns are filled for **all** seller
endpoints (not just the first two modules), plus a GAPS section and a
backend-defects section. Every row is `Not started`.

## 5. Module build order

Ordered by dependency, not by §7's numbering:

| Order | Module | Depends on | Note |
|---|---|---|---|
| 1 | **M0 Foundation** | — | Far larger than §7 implies — see §0. Includes `test/` setup (§9) |
| 2 | **M1 Authentication** | M0 | Also delivers registration + approval-status screens |
| 3 | **M16 Image Uploads** | M1 | Pulled forward: M1's registration flow needs it (§7 says "build with the first module that needs it") |
| 4 | **M2 Store Management** | M1, M16 | Descoped — see G7 |
| 5 | **M6 Orders** | M1, M0 socket + FCM | Highest value and highest risk; earlier than §7's numbering. Everything else is management; this is the business |
| 6 | **M3 Categories** | M1, M16 | |
| 7 | **M4 Products** | M3, M16 | |
| 8 | **M5 Inventory** | M4 | |
| 9 | **M12 Notifications** | M1 | Partially descoped — G8 |
| 10 | **M8 Earnings** | M1 | |
| 11 | **M9 Wallet/Payouts** | M8 | Descoped — G6 |
| 12 | **M14 Seller Profile** | M1, M16 | |
| 13 | **M15 Settings & Logout** | all | Account deletion **blocked** — G5 |
| 14 | **M10 Offers** | M4 | Descoped from "Coupons" — G2 |
| 15 | ~~M7 Dashboard~~ | — | **Blocked — no endpoint (G1)** |
| 16 | ~~M11 Discounts~~ | — | **Blocked — no endpoint (G3)** |
| 17 | ~~M13 Reports~~ | — | **Blocked — no endpoint (G4)** |

## 6. Analyzer baseline

```
$ flutter --version
Flutter 3.41.6 • channel stable • Dart 3.11.4

$ flutter analyze
Analyzing quick_commerce_seller...
No issues found! (ran in 3.0s)
```

**Baseline: 0 errors, 0 warnings, 0 infos.** The §3.5/R16 bar is already met and
must stay met. Not run: `flutter test` (the default counter test passes but is
about to become meaningless), and no build or device runtime gates — there is no
app to build yet.

---

## 7. Gaps, contradictions, risks — and the questions I need answered

**Blocking (I cannot start M0 without these):**

- **Q1 — The reference app does not exist.** §2's entire inventory is absent from
  this repository (table in §0). Which is true?
  **(a)** The reference app lives elsewhere and should be provided — I read it and
  follow it literally, as §2 intends. *This is my recommendation; §2's patterns
  are specific enough that the real thing will resolve a dozen small decisions
  correctly.*
  **(b)** There is no reference app; build the foundation from scratch to §2's
  written description. Workable — §2 is unusually detailed — but M0 becomes a
  large module, and §11's "Reuse" checklist becomes vacuous.
  **(c)** Something else.

- **Q2 — Production base URL.** No `.env.example`, no documented host. `deploy/`
  contains only an nginx uploads config. I need the API origin (and whether the
  socket is the same host on `:5001` or proxied) before `AppConstants` can be
  written. Is there a running instance I can verify against (§10.4 requires it)?

- **Q3 — Adding dependencies.** §2.2's "already in `pubspec.yaml`" list is
  aspirational here; `pubspec.yaml` has none of them. Under R and §13 ("never add
  a dependency") I need **explicit approval to add the whole §2.2 set** —
  `flutter_riverpod`, `go_router`, `dio`, `flutter_secure_storage`,
  `cached_network_image`, `firebase_core`, `firebase_messaging`,
  `socket_io_client`, `image_picker`, `intl`, `flutter_local_notifications`,
  `shared_preferences`, `audioplayers`, `connectivity_plus`, `permission_handler`
  — before M0. I will add nothing beyond that list without asking again.
  *(`geolocator`, `geocoding`, `google_maps_flutter`, `in_app_update`,
  `in_app_review`, `android_intent_plus` I would defer to the module that needs
  them rather than adding speculatively.)*

- **Q4 — Firebase.** FCM is central to M6 and M12, and §2.14 wants guarded
  Firebase init in `main.dart`. There is no `google-services.json`, no
  `GoogleService-Info.plist`, and no Firebase project configured. Who provides
  these, and for which bundle/application id?

- **Q5 — Application id / bundle id / app name.** Currently
  `com.example.quick_commerce_seller`. What should ship? This must be settled
  before Firebase (Q4) and before any signed build.

**Blocking a specific module (not M0):**

- **Q6 — G1/G3/G4: M7 Dashboard, M11 Discounts, M13 Reports have no backend
  endpoints at all.** §7 requires them; R15 forbids building an unbacked screen;
  G2 forbids adding a backend endpoint. These three requirements are mutually
  exclusive. My recommendation: **drop M13 and M11, and descope M7** to a
  compact "today" view built only from `GET /finance` plus the existing paginated
  order list — explicitly not a metrics dashboard. Confirm, or authorise backend
  work by the backend owner.
- **Q7 — G5: account deletion.** The controller exists but was never wired to a
  route (`restaurant.routes.js:19` imports it; nothing uses it). **Google Play and
  the App Store both mandate in-app account deletion**, so M15 ships a
  store-rejectable app without it. One line in the backend fixes this; B8 forbids
  me writing it. Please route it, or tell me to ship M15 without deletion and
  accept the review risk.
- **Q8 — G2: coupons.** §7/M10 describes coupon codes with usage limits and
  redemption stats. The backend has an *offer* entity and nothing else. Descope
  M10 to offers and rename it?

**Non-blocking risks I will handle unless told otherwise:**

- **R-a — Single-device eviction (Q-free, just flagging).** I will distinguish the
  device-eviction 401 from an expiry 401 in the interceptor so it forces logout
  once instead of retrying. Without this the app refresh-loops.
- **R-b — Inconsistent pagination** (D4): per-endpoint parsing, no shared model.
- **R-c — Relative upload URLs:** the app will prefix them with the API origin.
- **R-d — `stockQty: null` ≠ `0`:** untracked and out-of-stock render differently.
- **R-e — Cover-image upload resets the store to `pending`** re-review. I will warn
  the seller in the UI before that upload.
- **R-f — `order_status_update` has five shapes.** Defensive parse + REST reconcile.
- **R-g — Localization.** §2.1 notes the reference app has an unused l10n setup and
  hardcoded English. Since nothing exists here, I propose **no l10n scaffolding**
  and hardcoded English, matching §7/M15's instruction to omit a dead language
  toggle. Say so if you want l10n from day one — retrofitting is expensive.
- **R-h — `GUIDELINES.md` divergence** (§2.4): noted once, as instructed. I will
  build feature-first (`lib/features/...`) and will not create `lib/data/`,
  `lib/domain/`, `lib/ui/`, `lib/di/`, or `lib/platform/`, nor edit
  `GUIDELINES.md`.
- **R-i — `optimization_flow.md` conflicts with MASTER_PROMPT** in two places:
  it prescribes **MVVM** and a **top-level feature folder set** (§2–§4) where
  MASTER_PROMPT mandates feature-first with per-feature layers, and it prescribes
  **Isar** (§8) where §8.7 explicitly forbids a local database without approval.
  Per §0's precedence order MASTER_PROMPT wins; I will follow its performance
  guidance (§8.9) and ignore the architecture and Isar prescriptions. Flagging
  rather than assuming.

**Two backend security defects found in passing** (reported per B8, not fixed):

- **D1 (high):** `GET /api/v1/fcm-tokens/test-set-token/:phone/:token` and
  `test-get-token/:phone` are **unauthenticated** — anyone can read or overwrite
  any user's push token from a phone number. Push hijacking.
- **D2 (high):** `GET /api/v1/food/payments/restaurant/:restaurantId/wallet` has
  no role guard — any authenticated user of any role can read any restaurant's
  wallet.

Neither blocks me. Both should reach the backend owner today.

---

## 8. What I am waiting for

Answers to **Q1–Q5** unblock M0. **Q6–Q8** can be answered later but before their
modules. Per §6/§14 I will not write production code until Phase 0 is approved.
