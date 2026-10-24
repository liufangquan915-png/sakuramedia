import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/listing/video_summary_grid.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';

/// 概览中的普通 VideoItem 区域。
///
/// 标题明确标注为“普通视频”，避免让用户误以为条目已经完成 JAV 元数据匹配。
class OverviewRecentVideosSliverSection extends StatelessWidget {
  const OverviewRecentVideosSliverSection({
    super.key,
    required this.items,
    required this.isLoading,
    required this.onVideoTap,
    required this.onViewAll,
    this.errorMessage,
  });

  final List<VideoItemListItemDto> items;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<VideoItemListItemDto> onVideoTap;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '最近添加的普通视频',
                  key: const Key('overview-recent-videos-title'),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
              ),
              AppTextButton(
                key: const Key('overview-recent-videos-view-all'),
                label: '查看更多',
                size: AppTextButtonSize.small,
                onPressed: onViewAll,
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.md)),
        VideoSummarySliver(
          items: items,
          isLoading: isLoading,
          errorMessage: errorMessage,
          onVideoTap: onVideoTap,
          emptyMessage: '暂无普通视频。这里不会自动进行 JavDB 匹配。',
          placeholderCount: 4,
        ),
      ],
    );
  }
}
