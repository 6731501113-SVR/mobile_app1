# Merge notes

Base = Editor 1 (`lib/core`, `lib/features/{auth,home,borrow}`, `main.dart`).
Project name stays `frontend`, so android/web/assets from the original repo are unchanged.

| Part | Source | Location |
|---|---|---|
| Login, register, home, booking, my requests | Editor 1 | `lib/features/{auth,home,borrow}` |
| Payment screen (QR + slip upload), Fine screen | Editor 3 | `lib/features/renter/` |
| Admin menu + equipment/category/slip/return screens | Editor 2 | `lib/features/admin/` |

Editor 3's booking / my-loans screens were NOT used (Editor 1's replace them).

## Not verified
Flutter SDK was not available, so nothing was compiled or run. Run:
`flutter pub get && flutter analyze && flutter test`

## Things to settle with the backend
1. **Fine screen** is live: opened from a returned request with an unpaid fine.
   Optional JSON fields `deposit` and `price_per_day` on `/api/borrow-requests*`
   enable the deposit deduction; without them the fine is shown as "pay in full".
2. **Payment screen** shows only when the API sends `payment_due_at` and
   `payment_status` (`unpaid|rejected`) on a pending request. Editor 1's backend
   contract has no such fields, so the button is hidden today. Slip submission still
   goes to Editor 3's in-memory `AppStore` (mock) - it needs a real upload endpoint
   (`PaymentController.send()` is the single place to change).
3. **Admin endpoints differ**: Editor 2 uses `/api/borrow/pending-slips`,
   `/api/borrow/verify-slip/:id`, `/api/borrow/return/:id`, `/api/equipment`
   (PUT/multipart), `/api/categories`. Editor 1 uses `/api/borrow-requests...`.
   Base URL and the Bearer token are now shared (`ApiRepository.client`).
4. Admin "ส่งมอบ/รับคืน" still opens with Editor 2's demo values (request 101, deposit 500).
5. `dart:io` in Editor 2's equipment form / repository breaks **Flutter web**
   builds (Android/iOS fine).
6. `pubspec.lock` was removed (dependencies changed); `flutter pub get` regenerates it.
