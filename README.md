# chakudya_sdk

Dart and Flutter client for the **Chakudya Nutrition Registry (CNR)**, the open food and clinical nutrition API at `api.chakudya.xyz`. It covers the same routes as the JavaScript SDK (API 1.83.0): 64 namespaces, about 320 methods.

## Install

```yaml
dependencies:
  chakudya_sdk:
    git:
      url: https://github.com/edisontaimu9-ui/chakudya-dart.git
```

## Use

```dart
import 'package:chakudya_sdk/chakudya_sdk.dart';

final cnr = ChakudyaClient(apiKey: const String.fromEnvironment('CHAKUDYA_KEY'));

final maize = await cnr.foods.search(query: {'q': 'maize'});
final growth = await cnr.growth.assess(query: {'sex': 'female', 'age_months': 12, 'weight_kg': 9});
final dri = await cnr.dri.list(query: {'life_stage': 'female_19_30'});
```

Rules for every method:

- Path parameters are positional: `cnr.foods.get(9)`.
- GET and DELETE take `query:`. POST, PUT and PATCH take `body:` and an optional `query:`.
- Results are the decoded `data` field (`dynamic`: a `Map` or `List`).
- Errors throw `ChakudyaApiException` with `statusCode`, `message` and `body`. Timeouts and network failures have `statusCode` 0.

Typed helpers: `foods`, `exchange`, `renal` and `formulas` (list, get, create, update, replace, remove), `foods.autocomplete`, `packaged`, `rag.retrieve`, `memory.write` and `memory.recall`.

## Flutter example

```dart
FutureBuilder<dynamic>(
  future: cnr.foods.search(query: {'q': 'cassava'}),
  builder: (context, snap) {
    if (snap.hasError) return Text('${snap.error}');
    if (!snap.hasData) return const CircularProgressIndicator();
    final foods = snap.data as List;
    return ListView(children: [for (final f in foods) ListTile(title: Text('${f['food_name']}'))]);
  },
)
```

Run with: `flutter run --dart-define=CHAKUDYA_KEY=cnr_...`

## Keys in mobile apps

An app can be unpacked, so anything inside it is public. Use a **consumer** key only, never an admin key. For a published app, put the key behind a gateway Worker like `chakudya-gateway` rather than shipping it in the APK.

## Regenerate

`tool/methods.json` is copied from the JS SDK's `scripts/methods.json`. After the API changes: copy the new file, run `python3 tool/generate.py`, then `dart test`.

## Develop

```
dart pub get
dart test
```

MIT licence.
