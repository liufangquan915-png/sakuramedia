class MediaLibraryScanSummaryDto {
  const MediaLibraryScanSummaryDto({
    required this.newCount,
    required this.movedCount,
    required this.missingCount,
    required this.unchangedCount,
  });

  factory MediaLibraryScanSummaryDto.fromJson(Map<String, dynamic> json) {
    return MediaLibraryScanSummaryDto(
      newCount: json['new'] as int? ?? 0,
      movedCount: json['moved'] as int? ?? 0,
      missingCount: json['missing'] as int? ?? 0,
      unchangedCount: json['unchanged'] as int? ?? 0,
    );
  }

  final int newCount;
  final int movedCount;
  final int missingCount;
  final int unchangedCount;
}

class NewMediaCandidateDto {
  const NewMediaCandidateDto({
    required this.filename,
    required this.relativePath,
    required this.sizeBytes,
    required this.libraryId,
    required this.stable,
  });

  factory NewMediaCandidateDto.fromJson(Map<String, dynamic> json) {
    return NewMediaCandidateDto(
      filename: json['filename'] as String,
      relativePath: json['relative_path'] as String,
      sizeBytes: json['size'] as int,
      libraryId: json['library_id'] as int,
      stable: json['stable'] as bool? ?? false,
    );
  }

  final String filename;
  final String relativePath;
  final int sizeBytes;
  final int libraryId;
  final bool stable;
}

class MovedMediaCandidateDto {
  const MovedMediaCandidateDto({
    required this.mediaId,
    required this.oldRelativePath,
    required this.newRelativePath,
    required this.matchBasis,
    required this.uniqueMatch,
  });

  factory MovedMediaCandidateDto.fromJson(Map<String, dynamic> json) {
    return MovedMediaCandidateDto(
      mediaId: json['media_id'] as int,
      oldRelativePath: json['old_relative_path'] as String,
      newRelativePath: json['new_relative_path'] as String,
      matchBasis: json['match_basis'] as String,
      uniqueMatch: json['unique_match'] as bool? ?? false,
    );
  }

  final int mediaId;
  final String oldRelativePath;
  final String newRelativePath;
  final String matchBasis;
  final bool uniqueMatch;
}

class MissingMediaCandidateDto {
  const MissingMediaCandidateDto({
    required this.mediaId,
    required this.oldRelativePath,
  });

  factory MissingMediaCandidateDto.fromJson(Map<String, dynamic> json) {
    return MissingMediaCandidateDto(
      mediaId: json['media_id'] as int,
      oldRelativePath: json['old_relative_path'] as String,
    );
  }

  final int mediaId;
  final String oldRelativePath;
}

class MediaLibraryScanPreviewDto {
  const MediaLibraryScanPreviewDto({
    required this.libraryId,
    required this.summary,
    required this.newItems,
    required this.movedItems,
    required this.missingItems,
  });

  factory MediaLibraryScanPreviewDto.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> maps(String key) =>
        (json[key] as List<dynamic>? ?? const <dynamic>[])
            .cast<Map<String, dynamic>>();

    return MediaLibraryScanPreviewDto(
      libraryId: json['library_id'] as int,
      summary: MediaLibraryScanSummaryDto.fromJson(
        json['summary'] as Map<String, dynamic>,
      ),
      newItems: maps('new')
          .map(NewMediaCandidateDto.fromJson)
          .toList(growable: false),
      movedItems: maps('moved')
          .map(MovedMediaCandidateDto.fromJson)
          .toList(growable: false),
      missingItems: maps('missing')
          .map(MissingMediaCandidateDto.fromJson)
          .toList(growable: false),
    );
  }

  final int libraryId;
  final MediaLibraryScanSummaryDto summary;
  final List<NewMediaCandidateDto> newItems;
  final List<MovedMediaCandidateDto> movedItems;
  final List<MissingMediaCandidateDto> missingItems;
}
