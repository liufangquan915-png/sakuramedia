import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_scan_preview_dto.dart';

void main() {
  test('empty optional result lists parse as empty', () {
    final preview = MediaLibraryScanPreviewDto.fromJson(<String, dynamic>{
      'library_id': 3,
      'summary': <String, dynamic>{
        'new': 0,
        'moved': 0,
        'missing': 0,
        'unchanged': 124,
      },
    });

    expect(preview.libraryId, 3);
    expect(preview.summary.unchangedCount, 124);
    expect(preview.newItems, isEmpty);
    expect(preview.movedItems, isEmpty);
    expect(preview.missingItems, isEmpty);
  });

  test('stable flag defaults fail closed', () {
    final item = NewMediaCandidateDto.fromJson(<String, dynamic>{
      'filename': 'copying.mp4',
      'relative_path': 'incoming/copying.mp4',
      'size': 6291456,
      'library_id': 3,
    });

    expect(item.stable, isFalse);
  });
}
