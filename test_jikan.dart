import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  dio.options.baseUrl = 'https://api.jikan.moe/v4';

  print('Testing Jikan API...');

  try {
    final response = await dio.get(
      '/anime',
      queryParameters: {'q': 'Narut', 'page': 1, 'limit': 5},
    );

    print('Status: ${response.statusCode}');
    print('Data type: ${response.data.runtimeType}');

    if (response.data != null) {
      final data = response.data as Map<String, dynamic>;
      final mediaList = data['data'] as List?;
      print('Results count: ${mediaList?.length ?? 0}');

      if (mediaList != null && mediaList.isNotEmpty) {
        print('First result: ${mediaList[0]['title']}');
      }
    }
  } catch (e, stackTrace) {
    print('Error: $e');
    print('Stack: $stackTrace');
  }
}
