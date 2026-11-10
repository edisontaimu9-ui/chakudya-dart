import 'package:chakudya_sdk/chakudya_sdk.dart';

// dart run example/main.dart  (set the key with: dart run -DCHAKUDYA_KEY=cnr_... example/main.dart)
Future<void> main() async {
  final cnr = ChakudyaClient(apiKey: const String.fromEnvironment('CHAKUDYA_KEY'));
  try {
    final maize = await cnr.foods.search(query: {'q': 'maize'});
    print(maize);

    final growth = await cnr.growth.assess(
      body: {'sex': 'female', 'age_months': 12, 'weight_kg': 9},
    );
    print(growth);

    final dri = await cnr.dri.list(query: {'life_stage': 'female_19_30'});
    print(dri);
  } on ChakudyaApiException catch (e) {
    print('API error ${e.statusCode}: ${e.message}');
  } finally {
    cnr.close();
  }
}
