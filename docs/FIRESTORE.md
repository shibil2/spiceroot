# Kerala Rate — Firestore schema

Project: **kerala-rate**

## Collection: `products`

| Field | Type | Example |
|-------|------|---------|
| `nameEn` | String | `"Arecanut"` |
| `nameMl` | String | `"അടക്ക"` |
| `unit` | String | `"per kg"` |
| `district` | String | `"Kasaragod"` |
| `currentPrice` | Number | `420` |
| `yesterdayPrice` | Number | `408` |
| `weekHigh` | Number | `435` |
| `weekLow` | Number | `398` |
| `updatedAt` | Timestamp | server time |
| `history` | Array\<Map\> | `[{ "date": "2026-05-21", "price": 420 }, ...]` |

**Document IDs (slugs):**

| ID | Product |
|----|---------|
| `arecanut` | Arecanut |
| `black_pepper` | Black Pepper |
| `cardamom` | Cardamom |
| `rubber_rss4` | Rubber RSS4 |
| `coconut` | Coconut |
| `ginger_dry` | Ginger dry |
| `coffee_robusta` | Coffee Robusta |
| `nutmeg` | Nutmeg |
| `cloves` | Cloves |
| `turmeric` | Turmeric |

## Collection: `admin`

**Document:** `config`

| Field | Type | Example |
|-------|------|---------|
| `lastUpdated` | Timestamp | |
| `updatedBy` | String | `admin@keralarate.app` |
| `marketMessage` | String | `Arecanut arrivals high at Mangaluru APMC today` |

## Seed from the app (debug)

After signing in as an admin (or with permissive rules in dev), call:

```dart
await FirestoreService().seedDatabase();
```

Or run once from Firebase Console → Firestore → import using the structure above.

## Security rules (starter — tighten for production)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /products/{id} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    match /admin/config {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

## FlutterFire

Regenerate `lib/firebase_options.dart` after adding iOS/web apps:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=kerala-rate
```
