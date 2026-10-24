import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/overview/presentation/providers/overview_recent_videos_provider.dart';
import 'package:sakuramedia/features/videos/data/api/videos_api.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';

import '../../../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late ProviderContainer container;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-10-24T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [
        videosApiProvider.overrideWithValue(VideosApi(apiClient: apiClient)),
      ],
      retry: (_, __) => null,
    );
  });

  tearDown(() {
    container.dispose();
    apiClient.dispose();
    sessionStore.dispose();
  });

  test('只读请求固定按入库时间倒序取前8条普通视频', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/videos',
      body: <String, dynamic>{
        'items': <dynamic>[
          _video(30, '最新普通视频'),
          _video(20, '较早普通视频'),
        ],
        'page': 1,
        'page_size': 8,
        'total': 2,
      },
    );

    final items = await container.read(overviewRecentVideosProvider.future);

    expect(items.map((item) => item.id), <int>[30, 20]);
    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/videos');
    expect(request.uri.queryParameters, containsPair('page', '1'));
    expect(request.uri.queryParameters, containsPair('page_size', '8'));
    expect(
      request.uri.queryParameters,
      containsPair('sort', 'created_at:desc'),
    );
  });
}

Map<String, dynamic> _video(int id, String title) => <String, dynamic>{
  'id': id,
  'title': title,
  'summary': '',
  'cover_image': null,
  'release_date': null,
  'duration_seconds': 60,
  'file_size_bytes': 6000000,
  'cover_width': 16,
  'cover_height': 9,
  'media_count': 1,
  'can_play': true,
  'collections': <dynamic>[],
  'created_at': '2026-10-24T10:00:00',
  'updated_at': '2026-10-24T10:00:00',
};
