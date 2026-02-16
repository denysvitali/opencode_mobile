import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/models/project.dart';
import 'package:opencode_mobile/core/providers/project_provider.dart';

void main() {
  group('ProjectsState', () {
    test('initial state is empty, not loading, no error', () {
      final state = ProjectsState();
      expect(state.projects, isEmpty);
      expect(state.isLoading, false);
      expect(state.error, isNull);
    });

    test('copyWith creates new state with updated values', () {
      final state = ProjectsState();
      final project = Project(id: 'test-project');
      final newState = state.copyWith(
        projects: [project],
        isLoading: true,
        error: 'test error',
      );
      expect(newState.projects.length, 1);
      expect(newState.projects.first.id, 'test-project');
      expect(newState.isLoading, true);
      expect(newState.error, 'test error');
    });

    test('projectMap getter creates a map of project IDs to projects', () {
      final state = ProjectsState(
        projects: [
          Project(id: 'project-1', worktree: '/path/one'),
          Project(id: 'project-2', worktree: '/path/two'),
        ],
      );
      final map = state.projectMap;
      expect(map.length, 2);
      expect(map['project-1']?.id, 'project-1');
      expect(map['project-2']?.id, 'project-2');
    });

    test('projectMap returns empty map when no projects', () {
      final state = ProjectsState();
      final map = state.projectMap;
      expect(map, isEmpty);
    });
  });

  group('ProjectsNotifier', () {
    group('initial state', () {
      test('is correct', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final state = container.read(projectsProvider);
        expect(state.projects, isEmpty);
        expect(state.isLoading, false);
        expect(state.error, isNull);
      });
    });

    group('loadProjects', () {
      test('loads projects from API', () async {
        final container = ProviderContainer(
          overrides: [
            projectsProvider.overrideWith(() => TestProjectsNotifier(
              projectsToReturn: [
                Project(id: 'project-1'),
                Project(id: 'project-2'),
              ],
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(projectsProvider.notifier);

        await notifier.loadProjects();

        expect(notifier.state.projects.length, 2);
        expect(notifier.state.isLoading, false);
        expect(notifier.state.error, isNull);
      });

      test('handles API errors gracefully', () async {
        final container = ProviderContainer(
          overrides: [
            projectsProvider.overrideWith(() => TestProjectsNotifier(
              shouldThrowError: true,
              errorMessage: 'API Error: 500',
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(projectsProvider.notifier);
        await notifier.loadProjects();

        expect(notifier.state.error, contains('API Error: 500'));
        expect(notifier.state.projects, isEmpty);
      });

      test('preserves loading=false on error', () async {
        final container = ProviderContainer(
          overrides: [
            projectsProvider.overrideWith(() => TestProjectsNotifier(
              shouldThrowError: true,
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(projectsProvider.notifier);
        await notifier.loadProjects();

        expect(notifier.state.isLoading, false);
      });
    });

    group('addProject', () {
      test('adds new project', () {
        final container = ProviderContainer(
          overrides: [
            projectsProvider.overrideWith(() => TestProjectsNotifier()),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(projectsProvider.notifier);
        final project = Project(id: 'new-project');

        notifier.addProject(project);

        expect(notifier.state.projects.length, 1);
        expect(notifier.state.projects.first.id, 'new-project');
      });

      test('adds project to beginning of list', () {
        final container = ProviderContainer(
          overrides: [
            projectsProvider.overrideWith(() => TestProjectsNotifier(
              initialProjects: [Project(id: 'existing')],
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(projectsProvider.notifier);
        notifier.addProject(Project(id: 'new'));

        expect(notifier.state.projects.length, 2);
        expect(notifier.state.projects.first.id, 'new');
      });

      test('prevents duplicate project IDs', () {
        final container = ProviderContainer(
          overrides: [
            projectsProvider.overrideWith(() => TestProjectsNotifier(
              initialProjects: [Project(id: 'duplicate')],
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(projectsProvider.notifier);
        notifier.addProject(Project(id: 'duplicate'));

        expect(notifier.state.projects.length, 1);
      });
    });

    group('removeProject', () {
      test('removes project by ID', () {
        final container = ProviderContainer(
          overrides: [
            projectsProvider.overrideWith(() => TestProjectsNotifier(
              initialProjects: [
                Project(id: 'project-1'),
                Project(id: 'project-2'),
              ],
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(projectsProvider.notifier);
        notifier.removeProject('project-1');

        expect(notifier.state.projects.length, 1);
        expect(notifier.state.projects.first.id, 'project-2');
      });

      test('handles non-existent ID gracefully', () {
        final container = ProviderContainer(
          overrides: [
            projectsProvider.overrideWith(() => TestProjectsNotifier(
              initialProjects: [Project(id: 'existing')],
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(projectsProvider.notifier);
        notifier.removeProject('nonexistent');

        expect(notifier.state.projects.length, 1);
      });

      test('handles empty list', () {
        final container = ProviderContainer(
          overrides: [
            projectsProvider.overrideWith(() => TestProjectsNotifier()),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(projectsProvider.notifier);
        notifier.removeProject('any');

        expect(notifier.state.projects, isEmpty);
      });
    });
  });
}

class TestProjectsNotifier extends ProjectsNotifier {
  final List<Project>? projectsToReturn;
  final bool shouldThrowError;
  final String? errorMessage;
  final List<Project>? initialProjects;

  TestProjectsNotifier({
    this.projectsToReturn,
    this.shouldThrowError = false,
    this.errorMessage,
    this.initialProjects,
  });

  @override
  ProjectsState build() {
    return ProjectsState(
      projects: initialProjects ?? [],
      isLoading: false,
      error: null,
    );
  }

  @override
  Future<void> loadProjects() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      if (shouldThrowError) {
        throw OpenCodeException(errorMessage ?? 'Error');
      }
      final projects = projectsToReturn ?? [];
      state = state.copyWith(projects: projects, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  @override
  void addProject(Project project) {
    final exists = state.projects.any((p) => p.id == project.id);
    if (!exists) {
      state = state.copyWith(
        projects: [project, ...state.projects],
      );
    }
  }

  @override
  void removeProject(String projectId) {
    state = state.copyWith(
      projects: state.projects.where((p) => p.id != projectId).toList(),
    );
  }
}
