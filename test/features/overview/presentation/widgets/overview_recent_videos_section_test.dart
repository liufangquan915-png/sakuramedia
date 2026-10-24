import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/overview_recent_videos_section.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  testWidgets('展示普通视频标题并把点击回调交给VideoItem路由', (tester) async {
    int? tappedVideoId;
    var viewAllCount = 0;
    await _pumpSection(
      tester,
      items: <VideoItemListItemDto>[_video(7219, '普通视频样本')],
      onVideoTap: (video) => tappedVideoId = video.id,
      onViewAll: () => viewAllCount += 1,
    );

    expect(find.text('最近添加的普通视频'), findsOneWidget);
    expect(find.text('普通视频样本'), findsOneWidget);
    expect(find.textContaining('JavDB'), findsNothing);

    await tester.tap(find.byKey(const Key('video-summary-card-tap-7219')));
    expect(tappedVideoId, 7219);

    await tester.tap(
      find.byKey(const Key('overview-recent-videos-view-all')),
    );
    expect(viewAllCount, 1);
  });

  testWidgets('空列表明确说明不会自动进行JavDB匹配', (tester) async {
    await _pumpSection(tester, items: const <VideoItemListItemDto>[]);

    expect(find.text('暂无普通视频。这里不会自动进行 JavDB 匹配。'), findsOneWidget);
  });

  testWidgets('局部错误只显示本区错误态', (tester) async {
    await _pumpSection(
      tester,
      items: const <VideoItemListItemDto>[],
      errorMessage: '普通视频加载失败，请稍后重试',
    );

    expect(find.text('普通视频加载失败，请稍后重试'), findsOneWidget);
    expect(find.text('最近添加的普通视频'), findsOneWidget);
  });
}

Future<void> _pumpSection(
  WidgetTester tester, {
  required List<VideoItemListItemDto> items,
  String? errorMessage,
  ValueChanged<VideoItemListItemDto>? onVideoTap,
  VoidCallback? onViewAll,
}) {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  return tester.pumpWidget(
    MaterialApp(
      theme: sakuraThemeData,
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            OverviewRecentVideosSliverSection(
              items: items,
              isLoading: false,
              errorMessage: errorMessage,
              onVideoTap: onVideoTap ?? (_) {},
              onViewAll: onViewAll ?? () {},
            ),
          ],
        ),
      ),
    ),
  );
}

VideoItemListItemDto _video(int id, String title) => VideoItemListItemDto(
  id: id,
  title: title,
  mediaCount: 1,
  canPlay: true,
  durationSeconds: 60,
  fileSizeBytes: 6000000,
  coverWidth: 16,
  coverHeight: 9,
  createdAt: DateTime.parse('2026-10-24T10:00:00'),
);
