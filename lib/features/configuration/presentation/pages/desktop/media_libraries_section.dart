import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_scan_preview_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/media_library_form.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/provider_config_form.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_provider_catalog_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/config_delete_helpers.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/media_import/data/media_import_source.dart';
import 'package:sakuramedia/features/media_import/presentation/providers/media_import_api_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_inline_action_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_skeleton.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';

class MediaLibrariesSection extends ConsumerStatefulWidget {
  const MediaLibrariesSection({super.key, required this.active});

  final bool active;

  @override
  ConsumerState<MediaLibrariesSection> createState() =>
      _MediaLibrariesSectionState();
}

class _MediaLibrariesSectionState extends ConsumerState<MediaLibrariesSection> {
  final Set<int> _scanningLibraries = <int>{};
  @override
  void didUpdateWidget(covariant MediaLibrariesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active) {
          unawaited(ref.read(mediaProviderCatalogProvider.notifier).reload());
        }
      });
    }
  }

  Future<List<MediaProviderDto>?> _loadCatalog({bool showError = true}) async {
    try {
      return await ref.read(mediaProviderCatalogProvider.future);
    } catch (error) {
      if (showError && mounted) {
        showToast(apiErrorMessage(error, fallback: 'Provider 目录加载失败，请稍后重试。'));
      }
      return null;
    }
  }

  Future<void> _refresh() {
    return Future.wait<void>([
      ref.read(mediaLibrariesProvider.notifier).reload(),
      ref.read(mediaProviderCatalogProvider.notifier).reload(),
    ]);
  }

  Future<void> _createLibrary() async {
    final providers = await _loadCatalog();
    if (!mounted || providers == null) {
      return;
    }
    if (providers.isEmpty) {
      showToast('暂无可用 Provider，请先在“插件”设置中安装并启用媒体 Provider。');
      return;
    }
    final payload = await showDialog<CreateMediaLibraryPayload>(
      context: context,
      builder: (_) => MediaLibraryDialog(title: '新增媒体库', providers: providers),
    );
    if (!mounted || payload == null) {
      return;
    }
    try {
      await ref.read(mediaLibrariesProvider.notifier).create(payload);
      showToast('媒体库已创建');
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '创建媒体库失败'));
    }
  }

  Future<void> _editLibrary(MediaLibraryDto library) async {
    final providers =
        await _loadCatalog(showError: false) ?? const <MediaProviderDto>[];
    if (!mounted) {
      return;
    }
    final payload = await showDialog<UpdateMediaLibraryPayload>(
      context: context,
      builder: (_) => MediaLibraryDialog(
        title: '编辑媒体库',
        providers: providers,
        initialLibrary: library,
      ),
    );
    if (!mounted || payload == null) {
      return;
    }
    try {
      await ref
          .read(mediaLibrariesProvider.notifier)
          .updateLibrary(libraryId: library.id, payload: payload);
      showToast('媒体库已更新');
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '更新媒体库失败'));
    }
  }

  Future<void> _deleteLibrary(MediaLibraryDto library) async {
    await showAppConfigDeleteConfirm(
      context: context,
      title: '删除媒体库',
      message: '确认删除媒体库“${library.name}”？该操作不可恢复。',
      onDelete: () =>
          ref.read(mediaLibrariesProvider.notifier).delete(library.id),
      successToast: '媒体库已删除',
      failureFallback: '删除媒体库失败',
    );
  }

  Future<void> _scanLibrary(MediaLibraryDto library) async {
    if (_scanningLibraries.contains(library.id)) return;
    setState(() => _scanningLibraries.add(library.id));
    try {
      final preview = await ref
          .read(mediaLibrariesApiProvider)
          .scanPreview(library.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _MediaLibraryScanDialog(
          library: library,
          preview: preview,
          onImport: _importCandidate,
          onRefresh: () => ref
              .read(mediaLibrariesApiProvider)
              .scanPreview(library.id),
        ),
      );
    } catch (error) {
      if (mounted) {
        showToast(apiErrorMessage(error, fallback: '扫描媒体库失败'));
      }
    } finally {
      if (mounted) setState(() => _scanningLibraries.remove(library.id));
    }
  }

  Future<void> _importCandidate(NewMediaCandidateDto candidate) async {
    await ref.read(mediaImportApiProvider).createImport(
      mediaKind: 'video',
      libraryId: candidate.libraryId,
      source: MediaImportSource(
        sourceRef: <String, dynamic>{
          'version': 1,
          'kind': 'readonly_local_path',
          'relative_path': candidate.relativePath,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const SizedBox.shrink();
    final libraries = ref.watch(mediaLibrariesProvider);
    final content = libraries.when(
      loading: () => const AppSectionSkeleton(lineCount: 4),
      error: (error, _) => AppSectionError(
        title: '媒体库加载失败',
        message: apiErrorMessage(error, fallback: '媒体库加载失败，请稍后重试。'),
        onRetry: () => ref.read(mediaLibrariesProvider.notifier).reload(),
      ),
      data: (value) => _buildLoaded(context, value),
    );
    return AppPageRefreshScope(onRefresh: _refresh, child: content);
  }

  Widget _buildLoaded(BuildContext context, List<MediaLibraryDto> libraries) {
    final spacing = context.appSpacing;
    final catalog = ref.watch(mediaProviderCatalogProvider);
    final providers = catalog.value ?? const <MediaProviderDto>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppNoticeCard(
          leadingIcon: Icons.folder_open_outlined,
          title: '媒体库存储',
          description: '媒体库通过已安装的 Provider 连接存储；Provider 配置由插件目录动态提供。',
        ),
        SizedBox(height: spacing.lg),
        if (catalog.hasError)
          const AppNoticeCard(
            leadingIcon: Icons.warning_amber_rounded,
            description: 'Provider 目录暂不可用，已存在的媒体库仍可管理；新增或编辑配置前请重试。',
          ),
        if (catalog.hasError) SizedBox(height: spacing.lg),
        if (catalog.hasValue && providers.isEmpty)
          const AppNoticeCard(
            leadingIcon: Icons.extension_off_outlined,
            description: '暂无可用 Provider，请先在“插件”设置中安装并启用媒体 Provider。',
          ),
        if (catalog.hasValue && providers.isEmpty) SizedBox(height: spacing.lg),
        if (libraries.isEmpty)
          const AppEmptyState(message: '还没有媒体库')
        else
          AppSettingsGroup(
            dividerIndent: spacing.lg + spacing.xxl + spacing.md,
            children: [
              for (final library in libraries)
                _buildLibraryCell(
                  context,
                  library,
                  providers,
                  catalogReady: catalog.hasValue,
                ),
            ],
          ),
        SizedBox(height: spacing.lg),
        AppSettingsGroup(
          children: [
            AppSettingCell(
              key: const Key('configuration-media-library-create-button'),
              icon: Icons.add_rounded,
              iconColor: Theme.of(context).colorScheme.primary,
              title: '新增媒体库',
              titleTone: AppTextTone.accent,
              titleWeight: AppTextWeight.medium,
              trailing: const AppSettingCellChevron(),
              onTap: _createLibrary,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLibraryCell(
    BuildContext context,
    MediaLibraryDto library,
    List<MediaProviderDto> providers, {
    required bool catalogReady,
  }) {
    final provider = _findProvider(providers, library.providerKey);
    final unavailable = catalogReady && provider == null;
    return AppSettingCell(
      key: Key('media-library-card-${library.id}'),
      icon: Icons.folder_open_outlined,
      title: library.name,
      subtitle:
          provider?.displayName ??
          (catalogReady
              ? 'Provider 不可用 · ${library.providerKey}'
              : library.providerKey),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (unavailable)
            Text(
              '不可用',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.error,
              ),
            ),
          if (unavailable) SizedBox(width: context.appSpacing.sm),
          Text(
            'ID ${library.id}',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(width: context.appSpacing.sm),
          AppInlineActionButton(
            key: Key('media-library-scan-${library.id}'),
            icon: _scanningLibraries.contains(library.id)
                ? Icons.hourglass_top_rounded
                : Icons.manage_search_rounded,
            onTap: () => _scanLibrary(library),
          ),
          SizedBox(width: context.appSpacing.xs),
          AppInlineActionButton(
            key: Key('media-library-edit-${library.id}'),
            icon: Icons.edit_outlined,
            onTap: () => _editLibrary(library),
          ),
          SizedBox(width: context.appSpacing.xs),
          AppInlineActionButton(
            key: Key('media-library-delete-${library.id}'),
            icon: Icons.delete_outline,
            onTap: () => _deleteLibrary(library),
          ),
        ],
      ),
    );
  }
}

class _MediaLibraryScanDialog extends StatefulWidget {
  const _MediaLibraryScanDialog({
    required this.library,
    required this.preview,
    required this.onImport,
    required this.onRefresh,
  });

  final MediaLibraryDto library;
  final MediaLibraryScanPreviewDto preview;
  final Future<void> Function(NewMediaCandidateDto candidate) onImport;
  final Future<MediaLibraryScanPreviewDto> Function() onRefresh;

  @override
  State<_MediaLibraryScanDialog> createState() =>
      _MediaLibraryScanDialogState();
}

class _MediaLibraryScanDialogState extends State<_MediaLibraryScanDialog> {
  late MediaLibraryScanPreviewDto _preview = widget.preview;
  final Set<String> _importing = <String>{};

  Future<void> _import(NewMediaCandidateDto candidate) async {
    if (!candidate.stable || _importing.contains(candidate.relativePath)) return;
    setState(() => _importing.add(candidate.relativePath));
    try {
      await widget.onImport(candidate);
      final refreshed = await widget.onRefresh();
      if (!mounted) return;
      setState(() => _preview = refreshed);
      showToast('已提交导入，扫描结果已刷新');
    } catch (error) {
      if (mounted) showToast(apiErrorMessage(error, fallback: '加入媒体库失败'));
    } finally {
      if (mounted) setState(() => _importing.remove(candidate.relativePath));
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _preview.summary;
    return AlertDialog(
      key: Key('media-library-scan-dialog-${widget.library.id}'),
      backgroundColor: context.appColors.surfaceCard,
      title: Text(
        '扫描完成 · ${widget.library.name}',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s18,
          weight: AppTextWeight.semibold,
          tone: AppTextTone.primary,
        ),
      ),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '新增 ${summary.newCount}  ·  移动/改名 ${summary.movedCount}  ·  '
                '缺失 ${summary.missingCount}  ·  未变化 ${summary.unchangedCount}',
                key: const Key('media-library-scan-summary'),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.medium,
                  tone: AppTextTone.primary,
                ),
              ),
              if (_preview.newItems.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  '新增文件',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
                for (final item in _preview.newItems)
                  ListTile(
                    key: Key('scan-new-${item.relativePath}'),
                    title: Text(
                      item.filename,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        tone: AppTextTone.primary,
                      ),
                    ),
                    subtitle: Text(
                      '${item.relativePath}\n${item.sizeBytes} bytes',
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        tone: AppTextTone.muted,
                      ),
                    ),
                    isThreeLine: true,
                    trailing: SizedBox(
                      width: 112,
                      child: AppButton(
                        label: item.stable ? '加入媒体库' : '等待文件稳定',
                        size: AppButtonSize.xSmall,
                        isLoading: _importing.contains(item.relativePath),
                        onPressed: item.stable ? () => _import(item) : null,
                      ),
                    ),
                  ),
              ],
              if (_preview.movedItems.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  '移动或改名',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
                for (final item in _preview.movedItems)
                  ListTile(
                    key: Key('scan-moved-${item.mediaId}'),
                    title: Text(
                      'media ${item.mediaId}',
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        tone: AppTextTone.primary,
                      ),
                    ),
                    subtitle: Text(
                      '${item.oldRelativePath} → ${item.newRelativePath}\n'
                      '${item.matchBasis} · '
                      '检测到移动，当前版本暂不执行自动重绑',
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        tone: AppTextTone.muted,
                      ),
                    ),
                    isThreeLine: true,
                  ),
              ],
              if (_preview.missingItems.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  '当前未找到源文件',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
                for (final item in _preview.missingItems)
                  ListTile(
                    key: Key('scan-missing-${item.mediaId}'),
                    title: Text(
                      'media ${item.mediaId}',
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        tone: AppTextTone.primary,
                      ),
                    ),
                    subtitle: Text(
                      item.oldRelativePath,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        tone: AppTextTone.muted,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        AppButton(label: '关闭', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}

MediaProviderDto? _findProvider(
  List<MediaProviderDto> providers,
  String providerKey,
) {
  for (final provider in providers) {
    if (provider.providerKey == providerKey) return provider;
  }
  return null;
}

class MediaLibraryDialog extends StatefulWidget {
  const MediaLibraryDialog({
    super.key,
    required this.title,
    required this.providers,
    this.initialLibrary,
  });

  final String title;
  final List<MediaProviderDto> providers;
  final MediaLibraryDto? initialLibrary;

  @override
  State<MediaLibraryDialog> createState() => _MediaLibraryDialogState();
}

class _MediaLibraryDialogState extends State<MediaLibraryDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String? _selectedProviderKey;
  late ProviderConfigFormController _providerConfigController;

  bool get _isEditing => widget.initialLibrary != null;

  MediaProviderDto? get _selectedProvider =>
      _findProvider(widget.providers, _selectedProviderKey ?? '');

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialLibrary?.name ?? '',
    );
    _selectedProviderKey =
        widget.initialLibrary?.providerKey ??
        (widget.providers.isEmpty ? null : widget.providers.first.providerKey);
    _providerConfigController = ProviderConfigFormController(
      fields:
          _selectedProvider?.libraryConfigFields ??
          const <ProviderConfigFieldDto>[],
      initialConfig:
          widget.initialLibrary?.providerConfig ?? const <String, dynamic>{},
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _providerConfigController.dispose();
    super.dispose();
  }

  void _selectProvider(String? providerKey) {
    if (providerKey == null ||
        providerKey == _selectedProviderKey ||
        _isEditing) {
      return;
    }
    _providerConfigController.dispose();
    setState(() {
      _selectedProviderKey = providerKey;
      final provider = _findProvider(widget.providers, providerKey);
      _providerConfigController = ProviderConfigFormController(
        fields:
            provider?.libraryConfigFields ?? const <ProviderConfigFieldDto>[],
      );
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false) ||
        _selectedProviderKey == null) {
      return;
    }
    final value = MediaLibraryFormValue.fromControllers(
      nameController: _nameController,
      providerKey: _selectedProviderKey!,
      providerConfigController: _providerConfigController,
      isEditing: _isEditing,
    );
    if (_isEditing && _selectedProvider == null) {
      Navigator.of(context).pop(UpdateMediaLibraryPayload(name: value.name));
    } else if (_isEditing) {
      Navigator.of(context).pop(value.toUpdatePayload());
    } else {
      Navigator.of(context).pop(value.toCreatePayload());
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final provider = _selectedProvider;
    final unavailable = _isEditing && provider == null;
    return AppDesktopDialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: context.appLayoutTokens.dialogInsetPadding,
        vertical: context.appLayoutTokens.dialogInsetPadding,
      ),
      width: context.appLayoutTokens.dialogWidthMd,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s18,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              SizedBox(height: spacing.xl),
              MediaLibraryFormFields(
                nameController: _nameController,
                enabled: true,
                onNameSubmitted: (_) => _submit(),
              ),
              SizedBox(height: spacing.lg),
              if (!unavailable)
                MediaLibraryProviderSelectField(
                  providers: widget.providers,
                  value: _selectedProviderKey,
                  enabled: !_isEditing,
                  onChanged: _selectProvider,
                )
              else
                MediaLibraryProviderUnavailableNotice(
                  providerKey: widget.initialLibrary!.providerKey,
                ),
              if (provider != null &&
                  provider.libraryConfigFields.isNotEmpty) ...[
                SizedBox(height: spacing.lg),
                ProviderConfigFormFields(
                  controller: _providerConfigController,
                  isEditing: _isEditing,
                ),
              ],
              SizedBox(height: spacing.xl),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      onPressed: () => Navigator.of(context).pop(),
                      label: '取消',
                    ),
                  ),
                  SizedBox(width: spacing.md),
                  Expanded(
                    child: AppButton(
                      onPressed: _submit,
                      label: '保存',
                      variant: AppButtonVariant.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
