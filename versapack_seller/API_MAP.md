# API_MAP.md — Quick Commerce Seller App

Single source of truth linking the backend to the Flutter app.
Per MASTER_PROMPT.md §4.3. **Status** is `Not started` / `Wired` / `Verified`.

## Ground facts

| Fact | Value |
|------|-------|
| Backend location | `backend/quick-commerce/Backend` (Express + Mongo, ESM) |
| Global prefix | `/api` (`src/app.js:75`), versioned router mounts `/v1/...` |
| Seller role | **`RESTAURANT`** — quick commerce reuses the food-delivery restaurant entity |
| Seller route base | `/api/v1/food/restaurant` (`src/routes/index.js:45`) |
| **Base URL (live, verified)** | **`https://quick.appzeto.com/api/v1`** — per `FLUTTER_API_SPEC.md` ("Base URL: {HOST}/api/v1"). Socket: `https://quick.appzeto.com` |
| **Path convention** | The version lives in the base URL **only**. Repository paths are written as `/food/...`, never `/v1/food/...`. Splitting the version across both is how paths get a doubled or missing segment. |
| Local dev | API `PORT` 5000, socket `SOCKET_PORT` 5001. Override with `--dart-define=BASE_URL=...`. Note macOS AirPlay Receiver also binds `:5000` |
| Success envelope | `{ success: true, message, data }` (`src/utils/response.js:1`), `data` nullable |
| Error envelope | `{ success: false, message }` or `{ success:false, message, error }` (`errorHandler.js:36`) |
| Auth header | `Authorization: Bearer <accessToken>` (`auth.middleware.js:28`) |
| Access token TTL | 15m (`JWT_ACCESS_EXPIRES`) · Refresh 7d (`JWT_REFRESH_EXPIRES`) |
| Refresh path | `POST /api/v1/food/auth/refresh-token` — **note: not `/food/auth/...` only; a legacy `/api/v1/auth/*` alias exists** |
| Upload | multipart, see M16 |
| Socket | `/socket.io`, default namespace, room `restaurant:<restaurantId>` |

The envelope matches what MASTER_PROMPT §2.5 describes, so the planned Dio
response interceptor (unwrap `data` on `success:true`, reject with `ApiException`
on `success:false`) is correct — **with the deviations in the notes below.**

---

## M1 — Authentication

> Paths in the tables below are the **full server paths**. In Dart, drop the
> `/api/v1` prefix — it is already in `AppConstants.baseUrl`. So
> `/api/v1/food/auth/me` is called as `_dio.get('/food/auth/me')`.



| Module | Method | Path | Backend file:line | Auth | Request | Response (unwrapped) | Errors | Flutter repository | Flutter method | Model | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|
| M1 | POST | `/api/v1/food/auth/restaurant/request-otp` | `core/auth/auth.controller.js:84` | Public, rate-limited | `{ phone }` (8–15 chars) | `{ phone, otp? }` — `otp` echoed only when `NODE_ENV!=='production'` or `USE_DEFAULT_OTP=true` | 400 validation, 429 rate limit | `features/auth/data/auth_api.dart` | `requestOtp()` | — | Not started |
| M1 | POST | `/api/v1/food/auth/restaurant/verify-otp` | `core/auth/auth.controller.js:97` | Public, rate-limited | `{ phone, otp (4–6), fcmToken?, platform? }`, `platform` → `web`\|`mobile`, default `web` — **send `mobile`** | Either `{ needsRegistration: true, phone }` **or** `{ accessToken, refreshToken, user, needsRegistration: false }` | `Your restaurant registration is pending approval.` / `...has been rejected. Please contact support.` | `auth_api.dart` | `verifyOtp()` | polymorphic map (documented exception, §2.6) | Not started |
| M1 | POST | `/api/v1/food/auth/refresh-token` | `core/auth/auth.controller.js:74` | Refresh token in body | `{ refreshToken }` | `{ accessToken, ... }` | 401 | `dio_client.dart` (interceptor only) | — | — | Not started |
| M1 | POST | `/api/v1/food/auth/logout` | `core/auth/auth.controller.js:130` | Bearer | `{ refreshToken, fcmToken?, platform? }` | `{ invalidated: bool }` | — | `auth_api.dart` | `logout()` | — | Not started |
| M1 | GET | `/api/v1/food/auth/me` | `core/auth/auth.controller.js:145` | Bearer | — | Profile; for RESTAURANT includes both `name` and `restaurantName` | 401 | `auth_api.dart` | `me()` | `SellerModel` | Not started |
| M1 | POST | `/api/v1/food/restaurant/register` | `restaurant/controllers/restaurant.controller.js:35` | **Public**, multipart | fields `profileImage`, `panImage`, `gstImage`, `fssaiImage`, `menuImages[≤10]`, `coverImage`, `galleryImages[≤10]` + text fields | registered store | 400 validation | `features/registration/data/registration_repository.dart` | `register()` | `SellerModel` | Not started |
| M1 | POST | `/api/v1/food/restaurant/upload-attachment` | `restaurant.controller.js:25` | Public, multipart field `file` | file | `{ url, ... }` | 400 | `registration_repository.dart` | `uploadAttachment()` | — | Not started |
| M1 | POST | `/api/v1/fcm-tokens/mobile/save` | `core/notifications/fcm.routes.js:98` | Bearer | `{ token }` (forces `platform:'mobile'`) | `{ ownerType, ownerId, platform }` | — | `core/services/fcm_service.dart` | `registerToken()` | — | Not started |
| M1 | DELETE | `/api/v1/fcm-tokens/remove` | `fcm.routes.js:147` | Bearer | `{ token, platform? }` | — | — | `fcm_service.dart` | `removeToken()` | — | Not started |

**Auth notes — must shape the implementation:**

1. **OTP only.** There is no password login for `RESTAURANT` (password login is ADMIN-only, `auth.routes.js:38`). MASTER_PROMPT §7/M1's "read the backend, do not assume OTP" — read: it *is* OTP.
2. **Single-device eviction.** Every login `$inc`s `tokenVersion` (`auth.service.js:105`); `auth.middleware.js:70` 401s any token whose `tokenVersion` is stale with the message *"You have been signed out because this account was used on another device"*. Refresh tokens minted before the newer login are also stale, so **refresh will fail permanently, not transiently.** The refresh interceptor must not loop; it must surface this message distinctly from a plain expiry.
3. **Approval status is delivered as a login error**, not a field, for the never-approved case (`auth.service.js:402-416`). A `pending` store that has `approvedAt` set or has order history *is* allowed to log in (profile re-review). `AuthState` must model: logged out → OTP sent → needs registration → pending approval → rejected → authenticated.
4. Socket auth does **not** check `tokenVersion` — only the signature (`socket.js:14`). A socket can outlive an evicted session.

---

## M0 — Foundation

| Module | Method | Path | Backend file:line | Auth | Purpose | Status |
|---|---|---|---|---|---|---|
| M0 | GET | `/api/v1/health` | `routes/index.js:28` | Public | Base-URL reachability check | Not started |
| M0 | GET | `/api/v1/food/admin/business-settings/public` | `admin/controllers/businessSettings.controller.js` | Public | Business settings | Not started |
| M0 | GET | `/api/v1/food/admin/feature-settings/public` | `admin/controllers/admin.controller.js` | Public | Feature flags | Not started |
| M0 | GET | `/api/v1/food/admin/fee-settings/public` | `admin/controllers/admin.controller.js` | Public | Fee/GST fallback settings | Not started |
| M0 | GET | `/api/v1/food/admin/restaurant-subscription-settings/public` | `admin/controllers/admin.controller.js` | Public | Subscription plan settings | Not started |
| M0 | — | Socket `restaurant:<restaurantId>` | `config/socket.js:31,120` | Handshake `auth:{token}` | Auto-joined on connect for role RESTAURANT | Not started |

---

## M2 — Store Management

| Module | Method | Path | Backend file:line | Auth | Notes | Status |
|---|---|---|---|---|---|---|
| M2 | GET | `/api/v1/food/restaurant/current` | `restaurant.controller.js:76` | Bearer RESTAURANT | Own store profile | Not started |
| M2 | PATCH | `/api/v1/food/restaurant/profile` | `restaurant.controller.js:86` | Bearer RESTAURANT | **Location edits go to `pendingLocation`/`pendingZoneId` for admin moderation — do not expect immediate effect** | Not started |
| M2 | PATCH | `/api/v1/food/restaurant/availability` | `restaurant.controller.js:96` | Bearer RESTAURANT | Toggle `isAcceptingOrders` | Not started |
| M2 | GET | `/api/v1/food/restaurant/outlet-timings` | `outletTimings.controller.js:13` | Bearer RESTAURANT | Operating hours | Not started |
| M2 | PUT | `/api/v1/food/restaurant/outlet-timings` | `outletTimings.controller.js:23` | Bearer RESTAURANT | 7-day object, full replacement | Not started |
| M2 | POST | `/api/v1/food/restaurant/profile/profile-image` | `restaurant.controller.js:116` | Bearer, field `file` | Logo | Not started |
| M2 | POST | `/api/v1/food/restaurant/profile/cover-images` | `restaurant.controller.js:135` | Bearer, field `files` ≤20 | **Resets store status → `pending` (re-review).** Warn the seller before upload. | Not started |
| M2 | GET/POST/DELETE/PATCH | `/api/v1/food/restaurant/banners`, `/banners/order` | `restaurantBanner.controller.js:13,22,31,41` | Bearer RESTAURANT | Reorder payload must be a permutation | Not started |
| M2 | GET/POST/DELETE | `/api/v1/food/restaurant/media`, `/media/cover-image`, `/media/gallery` | `restaurantBanner.controller.js:51,60,69,78` | Bearer RESTAURANT | Cover + gallery | Not started |

---

## Remaining endpoints (backend columns filled; Flutter columns deferred to their module)

### M3 — Categories
| Method | Path | Backend file:line | Notes |
|---|---|---|---|
| GET | `/api/v1/food/restaurant/categories` | `restaurantCategory.controller.js:11` | Zone-aware. Returns `{ categories, total, page, limit }` — **non-standard pagination key** |
| POST | `/api/v1/food/restaurant/categories` | `restaurantCategory.controller.js:36` | `parentId` supports **one** nesting level; `parentId: ""` promotes to top level |
| PATCH | `/api/v1/food/restaurant/categories/:id` | `restaurantCategory.controller.js:46` | Cannot demote a category that has children |
| DELETE | `/api/v1/food/restaurant/categories/:id` | `restaurantCategory.controller.js:57` | Behaviour with products attached is server-defined — verify before building the confirm dialog copy |

### M4 — Product Management
| Method | Path | Backend file:line | Notes |
|---|---|---|---|
| GET | `/api/v1/food/restaurant/menu` | `restaurantMenu.controller.js:8` | Sections + items |
| PATCH | `/api/v1/food/restaurant/menu` | `restaurantMenu.controller.js:18` | Bulk menu edit |
| POST | `/api/v1/food/restaurant/foods` | `restaurantFood.controller.js:9` | Quick-commerce fields: `brand`, `packSize`, `mrp`, `gstRate`. Selling above `mrp` is refused |
| PATCH | `/api/v1/food/restaurant/foods/:id` | `restaurantFood.controller.js:42` | Also the only discount surface (see GAPS) |
| GET | `/api/v1/food/restaurant/bulk-upload/template` | `bulkUpload.controller.js:5` | `.xlsx` stream |
| POST | `/api/v1/food/restaurant/bulk-upload` | `bulkUpload.controller.js:26` | multipart field `file` |
| GET/POST/PATCH/DELETE | `/api/v1/food/restaurant/addons[/:id]` | `restaurantAddon.controller.js:10,21,32,44` | Add-ons |

### M5 — Inventory
| Method | Path | Backend file:line | Notes |
|---|---|---|---|
| PATCH | `/api/v1/food/restaurant/foods/stock` | `restaurantFood.controller.js:20` | Body is an array **or** `{ items: [...] }`; entry = `itemId` + any of `stockQty`, `lowStockThreshold`, `maxQtyPerOrder`, `isAvailable`. Max 500. Returns `{ updated, failed, updatedCount, failedCount }` — **per-item results; render partial failure, do not treat as all-or-nothing** |
| GET | `/api/v1/food/restaurant/foods/low-stock` | `restaurantFood.controller.js:32` | Returns `{ items, total }`, `total` = array length, **no pagination** |

**`stockQty: null` ≠ `0`.** `null` = untracked (legacy products), `0` = out of stock. The UI must not render them the same way. A product auto-hides at 0 and returns on restock — unless the seller switched it off by hand, which outranks the restock.

### M6 — Orders
| Method | Path | Backend file:line | Notes |
|---|---|---|---|
| GET | `/api/v1/food/restaurant/orders` | `orders/controllers/order.controller.js:175` | `?page&limit` (1–100, default 20) → `data.data` + `data.meta{total,page,limit,totalPages}` — **the only standard-paginated seller endpoint** |
| GET | `/api/v1/food/restaurant/orders/:orderId` | `order.controller.js:185` | Detail |
| PATCH | `/api/v1/food/restaurant/orders/:orderId/status` | `order.controller.js:196` | Accept / reject / advance. Server owns the state machine |
| POST | `/api/v1/food/restaurant/orders/:orderId/resend-notification` | `order.controller.js:408` | Re-ping delivery partners |

Socket events to a seller (room `restaurant:<id>`): `new_order`, `order_status_update`, `order_deleted`, `admin_notification`, `location-update`, `chat:message`, `chat:conversation_update`, `chat:typing`, `active_order` (reply to `emit('resync')`).
**`order_status_update` has five emitters with different field sets** (`order.service.js:1837`, `:394`, `order-delivery.service.js:112`, `:637`, `orderEmergencyRequest.service.js:181`). Only `orderId`/`orderMongoId` are always present. Parse defensively and always reconcile against a REST refetch.

FCM new-order push requires Android channel id **`new_order_channel`** exactly (`order.helpers.js:571`) — a different id gets silently demoted to a silent notification. Sent as two messages (data-only + notification) so Accept/Reject action buttons survive. `data` keys: `type`, `title`, `body`, `orderId`, `orderMongoId`, `orderDisplayId`, `link`, `customerName`, `itemCount`, `itemsList`, `address`, `total`, `paymentMethod`, `acceptanceDeadlineAt` — all stringified.

### M8 — Earnings
| Method | Path | Backend file:line | Notes |
|---|---|---|---|
| GET | `/api/v1/food/restaurant/finance` | `restaurantFinance.controller.js:4` | Summary incl. `netAvailable`. Pagination key is **`pagination`** not `meta`, with a redundant `pages` alongside `totalPages` |
| GET | `/api/v1/food/restaurant/subscription/overview` | `subscription.controller.js:21` | Current-month postpaid state |
| GET | `/api/v1/food/restaurant/subscription/invoices` | `subscription.controller.js:78` | `pagination` key |
| GET | `/api/v1/food/restaurant/subscription/invoices/:invoiceId` | `subscription.controller.js:110` | JSON only — **no PDF** |
| GET | `/api/v1/food/restaurant/subscription/transactions` | `subscription.controller.js:141` | Ledger |
| GET | `/api/v1/food/restaurant/subscription-history` | `restaurant.controller.js:184` | Legacy; flat `{ items, page, limit, total }` |

### M9 — Wallet / Payouts
| Method | Path | Backend file:line | Notes |
|---|---|---|---|
| POST | `/api/v1/food/restaurant/withdraw` | `withdrawal.controller.js:5` | Request payout |
| GET | `/api/v1/food/restaurant/withdrawals` | `withdrawal.controller.js:47` | **Bare array**, no envelope metadata, no pagination |
| GET | `/api/v1/food/payments/restaurant/:restaurantId/wallet` | `core/payments/payment.controller.js` | ⚠️ **No role guard** (`routes/index.js:65` applies `authMiddleware` only) — any authenticated user of any role can read any restaurant's wallet. Escalated in GAPS |

### M10 — Offers (not coupons — see GAPS)
| Method | Path | Backend file:line |
|---|---|---|
| GET | `/api/v1/food/restaurant/my-offers` | `restaurantOffer.controller.js:21` |
| POST | `/api/v1/food/restaurant/my-offers` | `restaurantOffer.controller.js:5` |
| PATCH | `/api/v1/food/restaurant/my-offers/:id/status` | `restaurantOffer.controller.js:42` |
| DELETE | `/api/v1/food/restaurant/my-offers/:id` | `restaurantOffer.controller.js:31` |

### M12 — Notifications
| Method | Path | Backend file:line | Notes |
|---|---|---|---|
| GET | `/api/v1/food/notifications/inbox` | `notification.controller.js:10` | Role USER/RESTAURANT/DELIVERY_PARTNER |
| PATCH | `/api/v1/food/notifications/:id/read` | `notification.controller.js:24` | Mark one read |
| DELETE | `/api/v1/food/notifications/:id` | `notification.controller.js:37` | Dismiss one |
| DELETE | `/api/v1/food/notifications/inbox/all` | `notification.controller.js:50` | Dismiss all |

**No `mark all read`** and **no unread-count endpoint** — the badge must be derived from the inbox page, which is only correct for the first page. Logged in GAPS.

### M14/M15 — Profile, Support, Settings
| Method | Path | Backend file:line |
|---|---|---|
| GET | `/api/v1/food/restaurant/complaints` | `restaurant.controller.js:164` |
| POST | `/api/v1/food/restaurant/support/tickets` | `supportTicket.controller.js:9` |
| GET | `/api/v1/food/restaurant/support/tickets` | `supportTicket.controller.js:52` |
| POST | `/api/v1/food/restaurant/feedback-experience` | `admin/controllers/feedbackExperience.controller.js:8` |
| GET | `/api/v1/food/restaurant/app-banners` | `admin/controllers/restaurantAppBanner.controller.js:45` |

### M16 — Image Uploads
| Method | Path | Backend file:line | Notes |
|---|---|---|---|
| POST | `/api/v1/uploads/image?folder=<path>` | `uploads/controllers/upload.controller.js:17` | **No auth**, rate-limited. multipart, field **`file`**, single file. Max **5 MB** (`UPLOAD_MAX_FILE_SIZE_MB`). MIME allowlist: `image/jpeg, image/jpg, image/png, image/webp, image/gif`. Returns `{ url, path, filename, mimeType, size }` — values are post-optimization (server re-encodes to WebP q90, max width 2560) |

⚠️ **Two upload paths with different limits.** Restaurant-module routes (`/register`, `/media/*`, `/bulk-upload`) use a *different* multer (`src/middleware/upload.js:21`) with a **25 MB** limit and **no MIME filter**. Client-side validation must be per-endpoint, not global.

⚠️ **`url` is usually relative** (`/uploads/...`) — `buildPublicUrl` refuses to persist localhost URLs (`storage.service.js:51`) and `UPLOAD_BASE_URL` defaults to relative in both dev and prod. **The app must prefix relative media URLs with the API origin itself.**

---

## GAPS — escalated, not implemented

Per §4.3 and §5.4, these are module requirements in MASTER_PROMPT.md §7 with **no backing endpoint**. Under R15 the corresponding screens are **not built** until resolved.

| # | Module | Required by §7 | Backend reality | Proposed resolution |
|---|---|---|---|---|
| G1 | **M7 Dashboard** | "Today's metrics from the backend's dashboard/summary endpoint. If a metric has no endpoint, it is a GAP; do not compute it by summing a list." | **No `/dashboard`, `/stats`, `/summary`, or `/analytics` route exists for a seller.** Only `GET /finance` (money) and `GET /orders` (list) | M7 cannot be built as specified. Either descope M7 to what `/finance` returns, or a backend endpoint is needed (violates G2 "zero new backend"). **Decision required.** |
| G2 | **M10 Coupons** | Code, type, min order, max discount, per-user usage limits, redemption stats | Only `/my-offers` — an offer/promo entity. **No coupon-code entity, no usage limits, no redemption stats** | Descope M10 to the offer entity and rename the module, or drop it. **Decision required.** |
| G3 | **M11 Discounts** | Product- and category-level discounts, scheduled offers, bulk application | **No discount route.** Item-level only via `PATCH /foods/:id` price fields. No store-wide or category-wide discount | Descope to per-product price edit (already M4), or drop M11. **Decision required.** |
| G4 | **M13 Reports** | Sales/order/product/inventory reports, export | **No report endpoint. No export.** The only file endpoint is the bulk-*import* template | §7 M13 explicitly forbids generating reports client-side (R9). **M13 cannot be built. Drop or escalate to backend.** |
| G5 | **M15 Account deletion** | "hard confirmation → the backend's delete endpoint" | `deleteCurrentRestaurantAccountController` **exists** (`restaurant.controller.js:174`) and is **imported at `restaurant.routes.js:19` but never wired to a route.** Dead import | **This blocks Google Play and App Store review** — both mandate in-app account deletion. One route line in the backend fixes it, but R7/B8 forbid me touching backend files. **Escalate to the backend owner.** |
| G6 | **M9 Wallet** | Available / pending / on-hold balances, typed ledger, withdrawal limits | Withdrawals are create+list only (no cancel, no detail, no bank-account CRUD). The wallet read is `/food/payments/restaurant/:restaurantId/wallet` with **no role guard** | Build M9 on `/finance` + `/withdraw` + `/withdrawals`. Do **not** build on the unguarded wallet route until it is fixed |
| G7 | **M2 Delivery settings / zones** | Radius, minimum order, delivery fee, prep time, serviceable area | **No seller-facing zone or delivery-config route.** Zone is admin-owned; a seller location change lands in `pendingLocation` for moderation | Descope M2 to profile + availability + outlet timings + media. Surface zone as read-only |
| G8 | **M12 Notifications** | Mark-all-read, unread badge count | No mark-all-read endpoint (only dismiss-all, which is destructive) and no count endpoint | Omit mark-all-read; derive the badge from page 1 only and label it as such, or escalate |
| G9 | **M14 Profile** | Change phone/email flows; KYC document status + rejection reasons | No change-phone/change-email route. Documents upload via `/register` and `/upload-attachment`; approval enum exists on the model | Verify the document status/rejection fields are exposed on `GET /current` before building |
| G10 | — | Seller's own ratings/reviews list | Only aggregate `rating` / `totalRatings` on `/current` | Show the aggregate only |

## Backend defects observed — reported, not fixed (R7 / B8)

| # | Severity | Finding |
|---|---|---|
| D1 | **High (security)** | `GET /api/v1/fcm-tokens/test-set-token/:phone/:token` and `GET /api/v1/fcm-tokens/test-get-token/:phone` (`fcm.routes.js:31,55`) are **unauthenticated**. Anyone can read or overwrite any user's push token by phone number — push hijacking. `GET /check` (`:21`) is also unauthenticated. |
| D2 | **High (security)** | `GET /api/v1/food/payments/restaurant/:restaurantId/wallet` has `authMiddleware` but **no role guard** (`routes/index.js:65`) — any authenticated user can read any restaurant's wallet. |
| D3 | Medium | `deleteCurrentRestaurantAccountController` imported but never routed — blocks app-store-mandated account deletion (G5). |
| D4 | Medium | Pagination is inconsistent across four shapes (`meta`, `pagination`, flat, none) and four list keys (`data`, `items`, `foods`, `categories`). Requires a per-endpoint parser rather than one shared paging model. |
| D5 | Low | `Backend/src/modules/food/orders/routes/order.routes.js` is imported nowhere — dead file. Do not build against it. |
| D6 | Low | `RESTAURANT_API_SPEC.md` does not document `PATCH /foods/stock`, `GET /foods/low-stock`, the chat surface, `POST /uploads/image`, or the wallet route. The route code is authoritative. |
| D7 | Low | Envelope deviations: `fcm.routes.js` hand-rolls its JSON; 404s at `fcm.routes.js:35,57` omit `data`; `/health` and `socket-server.js` return no `success` key. The Dio interceptor must tolerate a missing `data`. |
