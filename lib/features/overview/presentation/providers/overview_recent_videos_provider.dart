import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';

/// 概览页只读的最近普通视频摘要。
///
/// 独立于 PornBox 的分页状态，固定取首屏少量条目；不会触发元数据、缩略图
/// 或任何写操作。
final overviewRecentVideosProvider =
    FutureProvider.autoDispose<List<VideoItemListItemDto>>((ref) async {
      final page = await ref
          .read(videosApiProvider)
          .getVideos(page: 1, pageSize: 8, sort: 'created_at:desc');
      return page.items;
    });
