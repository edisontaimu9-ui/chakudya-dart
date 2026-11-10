import 'dart:convert';

import 'package:chakudya_sdk/chakudya_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

ChakudyaClient make(http.Response Function(http.Request) handler) => ChakudyaClient(
      apiKey: 'cnr_test',
      httpClient: MockClient((req) async => handler(req)),
    );

http.Response jsonRes(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  test('GET sends the bearer key and query, and unwraps data', () async {
    late http.Request seen;
    final c = make((req) {
      seen = req;
      return jsonRes({'status': 'success', 'data': [1, 2]});
    });
    final r = await c.foods.search(query: {'q': 'maize', 'empty': ''});
    expect(r, [1, 2]);
    expect(seen.method, 'GET');
    expect(seen.url.path, '/foods/search');
    expect(seen.url.queryParameters, {'q': 'maize'});
    expect(seen.headers['Authorization'], 'Bearer cnr_test');
  });

  test('POST sends a JSON body', () async {
    late http.Request seen;
    final c = make((req) {
      seen = req;
      return jsonRes({'status': 'success', 'data': {'ok': true}});
    });
    final r = await c.activityEnergy.calculate(body: {'sex': 'female', 'age_months': 12, 'weight_kg': 9});
    expect(r, {'ok': true});
    expect(seen.method, 'POST');
    expect(seen.url.path, '/activity-energy/calculate');
    expect(jsonDecode(seen.body)['age_months'], 12);
    expect(seen.headers['Content-Type'], 'application/json');
  });

  test('path parameters are encoded', () async {
    late http.Request seen;
    final c = make((req) {
      seen = req;
      return jsonRes({'status': 'success', 'data': {}});
    });
    await c.foods.get('a b/c');
    expect(seen.url.toString(), contains('/foods/a%20b%2Fc'));
  });

  test('401 throws ChakudyaApiException with the status', () async {
    final c = make((_) => jsonRes({'status': 'error', 'message': 'API key required'}, 401));
    expect(
      c.admin.overview(),
      throwsA(isA<ChakudyaApiException>()
          .having((e) => e.statusCode, 'statusCode', 401)
          .having((e) => e.message, 'message', 'API key required')),
    );
  });

  test('non-JSON replies come back as text', () async {
    final c = make((_) => http.Response('a,b\n1,2', 200, headers: {'content-type': 'text/csv'}));
    expect(await c.export.reference(), 'a,b\n1,2');
  });

  test('pediatric is an alias of paediatric', () {
    final c = make((_) => jsonRes({}));
    expect(identical(c.pediatric, c.paediatric), isTrue);
  });
}
