import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models/worktree.dart';

void main() {
  group('Worktree', () {
    group('fromJson', () {
      test('parses path, branch, head', () {
        final json = {
          'path': '/home/user/project/worktree',
          'branch': 'feature-branch',
          'head': 'abc123def',
        };
        final worktree = Worktree.fromJson(json);
        expect(worktree.path, '/home/user/project/worktree');
        expect(worktree.branch, 'feature-branch');
        expect(worktree.head, 'abc123def');
      });

      test('handles missing fields with defaults', () {
        final json = <String, dynamic>{};
        final worktree = Worktree.fromJson(json);
        expect(worktree.path, '');
        expect(worktree.branch, '');
        expect(worktree.head, '');
      });

      test('handles partial json with only path', () {
        final json = {'path': '/home/user/wt'};
        final worktree = Worktree.fromJson(json);
        expect(worktree.path, '/home/user/wt');
        expect(worktree.branch, '');
        expect(worktree.head, '');
      });

      test('handles partial json with path and branch', () {
        final json = {
          'path': '/home/user/wt',
          'branch': 'main',
        };
        final worktree = Worktree.fromJson(json);
        expect(worktree.path, '/home/user/wt');
        expect(worktree.branch, 'main');
        expect(worktree.head, '');
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final worktree = Worktree(
          path: '/home/user/project/worktree',
          branch: 'feature-branch',
          head: 'abc123def',
        );
        final json = worktree.toJson();
        expect(json['path'], '/home/user/project/worktree');
        expect(json['branch'], 'feature-branch');
        expect(json['head'], 'abc123def');
      });

      test('produces valid JSON', () {
        final worktree = Worktree(
          path: '/home/user/wt',
          branch: 'main',
          head: 'abc123',
        );
        final jsonString = jsonEncode(worktree.toJson());
        expect(() => jsonDecode(jsonString), returnsNormally);
      });
    });
  });

  group('WorktreeCreateInput', () {
    group('toJson', () {
      test('includes branch when set', () {
        final input = WorktreeCreateInput(branch: 'new-feature');
        final json = input.toJson();
        expect(json['branch'], 'new-feature');
      });

      test('includes createBranch when set', () {
        final input = WorktreeCreateInput(createBranch: true);
        final json = input.toJson();
        expect(json['createBranch'], true);
      });

      test('includes branch and createBranch when set', () {
        final input = WorktreeCreateInput(
          branch: 'feature-branch',
          createBranch: true,
        );
        final json = input.toJson();
        expect(json['branch'], 'feature-branch');
        expect(json['createBranch'], true);
      });

      test('omits null fields', () {
        final input = WorktreeCreateInput();
        final json = input.toJson();
        expect(json, isEmpty);
      });

      test('omits branch when null', () {
        final input = WorktreeCreateInput(createBranch: false);
        final json = input.toJson();
        expect(json.containsKey('branch'), false);
        expect(json['createBranch'], false);
      });

      test('omits createBranch when null', () {
        final input = WorktreeCreateInput(branch: 'main');
        final json = input.toJson();
        expect(json.containsKey('createBranch'), false);
        expect(json['branch'], 'main');
      });

      test('produces valid JSON', () {
        final input = WorktreeCreateInput(
          branch: 'feature',
          createBranch: true,
        );
        final jsonString = jsonEncode(input.toJson());
        expect(() => jsonDecode(jsonString), returnsNormally);
      });
    });
  });

  group('WorktreeRemoveInput', () {
    group('toJson', () {
      test('includes directory', () {
        final input = WorktreeRemoveInput(directory: '/home/user/worktree');
        final json = input.toJson();
        expect(json['directory'], '/home/user/worktree');
      });

      test('produces valid JSON', () {
        final input = WorktreeRemoveInput(directory: '/path/to/wt');
        final jsonString = jsonEncode(input.toJson());
        expect(() => jsonDecode(jsonString), returnsNormally);
      });
    });
  });

  group('WorktreeResetInput', () {
    group('toJson', () {
      test('includes directory', () {
        final input = WorktreeResetInput(directory: '/home/user/worktree');
        final json = input.toJson();
        expect(json['directory'], '/home/user/worktree');
      });

      test('produces valid JSON', () {
        final input = WorktreeResetInput(directory: '/path/to/wt');
        final jsonString = jsonEncode(input.toJson());
        expect(() => jsonDecode(jsonString), returnsNormally);
      });
    });
  });
}
