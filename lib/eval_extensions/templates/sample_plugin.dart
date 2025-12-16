const String sampleAniyaPlugin = r'''
import 'dart:convert';

// Functions passed from host:
// httpGet(url, [headers])
// soupParse(html)
// sha256Hex(input)

dynamic search(String query, int page, List<dynamic> filters,
    Function httpGet, Function soupParse, Function sha256Hex) async {
  final res = httpGet('https://example.com/search?q=$query');
  final html = res is Future ? await res : res.toString();
  final soup = soupParse(html).toString();
  final items = <Map<String, dynamic>>[
    {
      'title': 'Example: ' + query,
      'url': 'https://example.com/item/1',
      'cover': '',
      'description': '',
      'episodes': [],
    }
  ];
  final pages = {'list': items, 'hasNextPage': false};
  return json.encode(pages);
}
''';
