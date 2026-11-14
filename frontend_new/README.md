# Equipment borrowing app (Flutter)

Mobile app for borrowing club equipment. Borrowers book items and pay by slip; admins approve, hand over and take items back.

## Run

```
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

`API_BASE_URL` is the backend address (default `http://localhost:3000`).
Android emulator: `http://10.0.2.2:3000` · real phone: `http://<your PC IP>:3000` · deployed: your `https://...` URL.

Check the code: `flutter analyze` and `flutter test`.

## Folder map

```
lib/
  main.dart            starts the app and picks the first screen
                       (login -> borrower home, or admin menu)
  core/                shared by every feature
    api_client.dart      the only place that talks HTTP (token, Thai error messages)
    models.dart          AppUser, Category, Equipment
    theme.dart           colours and app theme
    common_widgets.dart  small shared widgets
    dates.dart, format.dart, equipment_ui.dart   date / baht / status helpers
  features/
    auth/      login and register
    home/      equipment list with search and filters (borrower home)
    borrow/    book equipment on a calendar, "my requests" tab
    payment/   pay by slip upload, fine and deposit screen
    admin/     admin menu and its screens
test/          same folders as lib/ (helpers/fakes.dart = fake repositories)
```

Inside a feature the file names tell you what they do:

| Ending | Meaning |
|---|---|
| `*_page.dart`, `*_screen.dart` | what you see on screen |
| `*_controller.dart` | the logic of one screen (no widgets) |
| `*_repository.dart` | calls to the backend API |
| `*_models.dart` | data classes read from the API |

## How a rental goes

`pending` (borrower sends request) -> `approved` (admin approves, payment deadline starts)
-> borrower uploads the slip -> admin verifies it -> `borrowed` (admin hands over)
-> `returned` (admin takes it back; late/damage fine is calculated by the server).

| Step | Borrower screen | Admin screen |
|---|---|---|
| Request | `borrow/borrow_page.dart` | `admin/screens/admin_pending_borrow_screen.dart` |
| Pay | `payment/payment_screen.dart` | `admin/screens/admin_pending_slip_screen.dart` |
| Hand over / return | (status shown in `borrow/my_requests_page.dart`) | `admin/screens/admin_delivery_return_screen.dart` |
| Fine | `payment/fine_screen.dart` | same return screen |

## Where do I change...

| I want to change | Look in |
|---|---|
| a backend URL or request | the feature's `*_repository.dart` (admin: `admin/data/api_repository.dart`) |
| an error message shown to the user | `core/api_client.dart` (`translateBackendMessage`) |
| colours / fonts | `core/theme.dart` |
| the late-fine rate (30 baht/day) | `borrow/borrow_models.dart` (`kFinePerDay`) **and** `backend/controllers/borrowController.js` |
| how the status of a request is shown | `borrow/request_widgets.dart`, `borrow/my_requests_page.dart` |

## Good to know

- `payment/` has its own request model (`payment_models.dart`) that is richer than `borrow/borrow_models.dart`.
  `payment/request_adapter.dart` converts one into the other. Merging the two models into one would be a good next cleanup.
- `admin/` has its own small models (`admin/data/`) for the same reason.
