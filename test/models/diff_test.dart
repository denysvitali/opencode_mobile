import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models/diff.dart';

void main() {
  group('DiffHunk', () {
    group('fromJson', () {
      test('parses all hunk fields', () {
        final json = {
          'oldStart': 10,
          'oldLines': 5,
          'newStart': 12,
          'newLines': 7,
          'content': '@@ -10,5 +12,7 @@',
        };
        final hunk = DiffHunk.fromJson(json);
        expect(hunk.oldStart, 10);
        expect(hunk.oldLines, 5);
        expect(hunk.newStart, 12);
        expect(hunk.newLines, 7);
        expect(hunk.content, '@@ -10,5 +12,7 @@');
      });

      test('handles missing fields with defaults', () {
        final json = <String, dynamic>{};
        final hunk = DiffHunk.fromJson(json);
        expect(hunk.oldStart, 0);
        expect(hunk.oldLines, 0);
        expect(hunk.newStart, 0);
        expect(hunk.newLines, 0);
        expect(hunk.content, '');
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final hunk = DiffHunk(
          oldStart: 10,
          oldLines: 5,
          newStart: 12,
          newLines: 7,
          content: '@@ -10,5 +12,7 @@',
        );
        final json = hunk.toJson();
        expect(json['oldStart'], 10);
        expect(json['oldLines'], 5);
        expect(json['newStart'], 12);
        expect(json['newLines'], 7);
        expect(json['content'], '@@ -10,5 +12,7 @@');
      });

      test('produces valid JSON', () {
        final hunk = DiffHunk(
          oldStart: 1,
          oldLines: 10,
          newStart: 1,
          newLines: 15,
          content: 'test content',
        );
        final jsonString = jsonEncode(hunk.toJson());
        expect(() => jsonDecode(jsonString), returnsNormally);
      });
    });
  });

  group('FileDiff', () {
    group('fromJson', () {
      test('parses basic file diff', () {
        final json = {
          'path': 'src/main.dart',
          'status': 'modified',
          'additions': 10,
          'deletions': 5,
        };
        final fileDiff = FileDiff.fromJson(json);
        expect(fileDiff.path, 'src/main.dart');
        expect(fileDiff.status, 'modified');
        expect(fileDiff.additions, 10);
        expect(fileDiff.deletions, 5);
      });

      test('parses nested hunks array', () {
        final json = {
          'path': 'src/main.dart',
          'status': 'modified',
          'hunks': [
            {
              'oldStart': 10,
              'oldLines': 5,
              'newStart': 12,
              'newLines': 7,
              'content': '@@ -10,5 +12,7 @@',
            },
            {
              'oldStart': 20,
              'oldLines': 3,
              'newStart': 22,
              'newLines': 4,
              'content': '@@ -20,3 +22,4 @@',
            },
          ],
        };
        final fileDiff = FileDiff.fromJson(json);
        expect(fileDiff.hunks.length, 2);
        expect(fileDiff.hunks[0].oldStart, 10);
        expect(fileDiff.hunks[1].oldStart, 20);
      });

      test('handles missing optional fields', () {
        final json = <String, dynamic>{
          'path': 'src/main.dart',
        };
        final fileDiff = FileDiff.fromJson(json);
        expect(fileDiff.path, 'src/main.dart');
        expect(fileDiff.oldPath, isNull);
        expect(fileDiff.status, 'modified');
        expect(fileDiff.additions, 0);
        expect(fileDiff.deletions, 0);
        expect(fileDiff.hunks, isEmpty);
        expect(fileDiff.content, isNull);
      });

      test('parses oldPath for renamed files', () {
        final json = {
          'path': 'src/new_name.dart',
          'oldPath': 'src/old_name.dart',
          'status': 'renamed',
        };
        final fileDiff = FileDiff.fromJson(json);
        expect(fileDiff.oldPath, 'src/old_name.dart');
      });

      test('parses content field', () {
        final json = {
          'path': 'src/main.dart',
          'content': 'file content here',
        };
        final fileDiff = FileDiff.fromJson(json);
        expect(fileDiff.content, 'file content here');
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final fileDiff = FileDiff(
          path: 'src/main.dart',
          oldPath: 'src/old.dart',
          status: 'modified',
          additions: 10,
          deletions: 5,
          hunks: [
            DiffHunk(
              oldStart: 1,
              oldLines: 5,
              newStart: 1,
              newLines: 7,
              content: 'test',
            ),
          ],
          content: 'file content',
        );
        final json = fileDiff.toJson();
        expect(json['path'], 'src/main.dart');
        expect(json['oldPath'], 'src/old.dart');
        expect(json['status'], 'modified');
        expect(json['additions'], 10);
        expect(json['deletions'], 5);
        expect((json['hunks'] as List).length, 1);
        expect(json['content'], 'file content');
      });

      test('omits null fields', () {
        final fileDiff = FileDiff(
          path: 'src/main.dart',
          status: 'modified',
        );
        final json = fileDiff.toJson();
        expect(json.containsKey('oldPath'), false);
        expect(json.containsKey('content'), false);
      });

      test('produces valid JSON', () {
        final fileDiff = FileDiff(
          path: 'src/main.dart',
          status: 'modified',
          additions: 10,
          deletions: 5,
        );
        final jsonString = jsonEncode(fileDiff.toJson());
        expect(() => jsonDecode(jsonString), returnsNormally);
      });
    });

    group('isBinary', () {
      test('returns true when status is binary', () {
        final fileDiff = FileDiff(path: 'test.bin', status: 'binary');
        expect(fileDiff.isBinary, true);
      });

      test('returns false when status is not binary', () {
        final fileDiff = FileDiff(path: 'test.dart', status: 'modified');
        expect(fileDiff.isBinary, false);
      });
    });

    group('isAdded', () {
      test('returns true when status is added', () {
        final fileDiff = FileDiff(path: 'new.dart', status: 'added');
        expect(fileDiff.isAdded, true);
      });

      test('returns false when status is not added', () {
        final fileDiff = FileDiff(path: 'test.dart', status: 'modified');
        expect(fileDiff.isAdded, false);
      });
    });

    group('isDeleted', () {
      test('returns true when status is deleted', () {
        final fileDiff = FileDiff(path: 'deleted.dart', status: 'deleted');
        expect(fileDiff.isDeleted, true);
      });

      test('returns false when status is not deleted', () {
        final fileDiff = FileDiff(path: 'test.dart', status: 'modified');
        expect(fileDiff.isDeleted, false);
      });
    });

    group('isRenamed', () {
      test('returns true when status is renamed', () {
        final fileDiff = FileDiff(
          path: 'renamed.dart',
          oldPath: 'original.dart',
          status: 'renamed',
        );
        expect(fileDiff.isRenamed, true);
      });

      test('returns false when status is not renamed', () {
        final fileDiff = FileDiff(path: 'test.dart', status: 'modified');
        expect(fileDiff.isRenamed, false);
      });
    });

    group('isModified', () {
      test('returns true when status is modified', () {
        final fileDiff = FileDiff(path: 'test.dart', status: 'modified');
        expect(fileDiff.isModified, true);
      });

      test('returns false when status is not modified', () {
        final fileDiff = FileDiff(path: 'new.dart', status: 'added');
        expect(fileDiff.isModified, false);
      });
    });
  });

  group('SessionDiff', () {
    group('fromJson', () {
      test('parses files array', () {
        final json = {
          'files': [
            {'path': 'src/a.dart', 'status': 'modified', 'additions': 5, 'deletions': 2},
            {'path': 'src/b.dart', 'status': 'added', 'additions': 10, 'deletions': 0},
          ],
        };
        final sessionDiff = SessionDiff.fromJson(json);
        expect(sessionDiff.files.length, 2);
        expect(sessionDiff.files[0].path, 'src/a.dart');
        expect(sessionDiff.files[1].path, 'src/b.dart');
      });

      test('calculates totalAdditions from file sums', () {
        final json = {
          'files': [
            {'path': 'src/a.dart', 'additions': 5},
            {'path': 'src/b.dart', 'additions': 10},
            {'path': 'src/c.dart', 'additions': 3},
          ],
        };
        final sessionDiff = SessionDiff.fromJson(json);
        expect(sessionDiff.totalAdditions, 18);
      });

      test('calculates totalDeletions from file sums', () {
        final json = {
          'files': [
            {'path': 'src/a.dart', 'deletions': 2},
            {'path': 'src/b.dart', 'deletions': 4},
            {'path': 'src/c.dart', 'deletions': 1},
          ],
        };
        final sessionDiff = SessionDiff.fromJson(json);
        expect(sessionDiff.totalDeletions, 7);
      });

      test('handles empty files array', () {
        final json = {'files': <dynamic>[]};
        final sessionDiff = SessionDiff.fromJson(json);
        expect(sessionDiff.files, isEmpty);
        expect(sessionDiff.totalAdditions, 0);
        expect(sessionDiff.totalDeletions, 0);
      });

      test('handles missing files field', () {
        final json = <String, dynamic>{};
        final sessionDiff = SessionDiff.fromJson(json);
        expect(sessionDiff.files, isEmpty);
        expect(sessionDiff.totalAdditions, 0);
        expect(sessionDiff.totalDeletions, 0);
      });
    });
  });
}
