import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models/provider.dart';

void main() {
  group('ProviderModel', () {
    group('fromJson', () {
      test('parses basic model with id, name', () {
        final json = {
          'id': 'gpt-4',
          'name': 'GPT-4',
        };
        final model = ProviderModel.fromJson(json);
        expect(model.id, 'gpt-4');
        expect(model.name, 'GPT-4');
      });

      test('parses cost.input and cost.output', () {
        final json = {
          'id': 'gpt-4',
          'name': 'GPT-4',
          'cost': {
            'input': 0.03,
            'output': 0.06,
          },
        };
        final model = ProviderModel.fromJson(json);
        expect(model.costInput, 0.03);
        expect(model.costOutput, 0.06);
      });

      test('parses cost as int values', () {
        final json = {
          'id': 'gpt-4',
          'name': 'GPT-4',
          'cost': {
            'input': 1,
            'output': 2,
          },
        };
        final model = ProviderModel.fromJson(json);
        expect(model.costInput, 1.0);
        expect(model.costOutput, 2.0);
      });

      test('parses limit.context and limit.output', () {
        final json = {
          'id': 'gpt-4',
          'name': 'GPT-4',
          'limit': {
            'context': 128000,
            'output': 16384,
          },
        };
        final model = ProviderModel.fromJson(json);
        expect(model.contextWindow, 128000);
        expect(model.maxOutput, 16384);
      });

      test('parses limit as int values', () {
        final json = {
          'id': 'gpt-4',
          'name': 'GPT-4',
          'limit': {
            'context': 8192,
            'output': 4096,
          },
        };
        final model = ProviderModel.fromJson(json);
        expect(model.contextWindow, 8192);
        expect(model.maxOutput, 4096);
      });

      test('handles missing optional fields', () {
        final json = {
          'id': 'gpt-4',
          'name': 'GPT-4',
        };
        final model = ProviderModel.fromJson(json);
        expect(model.id, 'gpt-4');
        expect(model.name, 'GPT-4');
        expect(model.costInput, isNull);
        expect(model.costOutput, isNull);
        expect(model.contextWindow, isNull);
        expect(model.maxOutput, isNull);
      });

      test('handles missing cost object', () {
        final json = {
          'id': 'gpt-4',
          'name': 'GPT-4',
          'limit': {'context': 128000},
        };
        final model = ProviderModel.fromJson(json);
        expect(model.costInput, isNull);
        expect(model.costOutput, isNull);
      });

      test('handles missing limit object', () {
        final json = {
          'id': 'gpt-4',
          'name': 'GPT-4',
          'cost': {'input': 0.03},
        };
        final model = ProviderModel.fromJson(json);
        expect(model.contextWindow, isNull);
        expect(model.maxOutput, isNull);
      });

      test('handles null id and name', () {
        final json = <String, dynamic>{};
        final model = ProviderModel.fromJson(json);
        expect(model.id, '');
        expect(model.name, '');
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final model = ProviderModel(
          id: 'gpt-4',
          name: 'GPT-4',
          costInput: 0.03,
          costOutput: 0.06,
          contextWindow: 128000,
          maxOutput: 16384,
        );
        final json = model.toJson();

        expect(json['id'], 'gpt-4');
        expect(json['name'], 'GPT-4');
        expect(json['cost']['input'], 0.03);
        expect(json['cost']['output'], 0.06);
        expect(json['limit']['context'], 128000);
        expect(json['limit']['output'], 16384);
      });

      test('omits null cost/limit objects', () {
        final model = ProviderModel(
          id: 'gpt-4',
          name: 'GPT-4',
        );
        final json = model.toJson();

        expect(json.containsKey('cost'), false);
        expect(json.containsKey('limit'), false);
      });

      test('omits costOutput when null', () {
        final model = ProviderModel(
          id: 'gpt-4',
          name: 'GPT-4',
          costInput: 0.03,
        );
        final json = model.toJson();

        expect(json['cost']['input'], 0.03);
        expect(json['cost'].containsKey('output'), false);
      });

      test('omits maxOutput when null', () {
        final model = ProviderModel(
          id: 'gpt-4',
          name: 'GPT-4',
          contextWindow: 128000,
        );
        final json = model.toJson();

        expect(json['limit']['context'], 128000);
        expect(json['limit'].containsKey('output'), false);
      });

      test('produces valid JSON', () {
        final model = ProviderModel(
          id: 'gpt-4',
          name: 'GPT-4',
          costInput: 0.03,
          contextWindow: 128000,
        );
        final jsonString = jsonEncode(model.toJson());
        expect(() => jsonDecode(jsonString), returnsNormally);
      });
    });
  });

  group('Provider', () {
    group('fromJson', () {
      test('parses basic provider', () {
        final json = {
          'id': 'openai',
          'name': 'OpenAI',
          'models': [
            {'id': 'gpt-4', 'name': 'GPT-4'},
          ],
        };
        final provider = Provider.fromJson(json);
        expect(provider.id, 'openai');
        expect(provider.name, 'OpenAI');
        expect(provider.models.length, 1);
        expect(provider.models[0].id, 'gpt-4');
      });

      test('handles models as Map (keyed by model ID)', () {
        final json = {
          'id': 'openai',
          'name': 'OpenAI',
          'models': {
            'gpt-4': {'name': 'GPT-4', 'cost': {'input': 0.03}},
            'gpt-3.5': {'name': 'GPT-3.5', 'cost': {'input': 0.001}},
          },
        };
        final provider = Provider.fromJson(json);
        expect(provider.models.length, 2);
        expect(provider.models[0].id, 'gpt-4');
        expect(provider.models[0].name, 'GPT-4');
        expect(provider.models[0].costInput, 0.03);
        expect(provider.models[1].id, 'gpt-3.5');
        expect(provider.models[1].name, 'GPT-3.5');
      });

      test('handles models as List', () {
        final json = {
          'id': 'openai',
          'name': 'OpenAI',
          'models': [
            {'id': 'gpt-4', 'name': 'GPT-4'},
            {'id': 'gpt-3.5', 'name': 'GPT-3.5'},
          ],
        };
        final provider = Provider.fromJson(json);
        expect(provider.models.length, 2);
        expect(provider.models[0].id, 'gpt-4');
        expect(provider.models[1].id, 'gpt-3.5');
      });

      test('handles models with full details', () {
        final json = {
          'id': 'openai',
          'name': 'OpenAI',
          'models': {
            'gpt-4': {
              'name': 'GPT-4',
              'cost': {'input': 0.03, 'output': 0.06},
              'limit': {'context': 128000, 'output': 16384},
            },
          },
        };
        final provider = Provider.fromJson(json);
        expect(provider.models[0].costInput, 0.03);
        expect(provider.models[0].costOutput, 0.06);
        expect(provider.models[0].contextWindow, 128000);
        expect(provider.models[0].maxOutput, 16384);
      });

      test('parses configured flag', () {
        final json = {
          'id': 'openai',
          'name': 'OpenAI',
          'configured': true,
        };
        final provider = Provider.fromJson(json);
        expect(provider.configured, true);
      });

      test('configured defaults to false when missing', () {
        final json = {
          'id': 'openai',
          'name': 'OpenAI',
        };
        final provider = Provider.fromJson(json);
        expect(provider.configured, false);
      });

      test('falls back to name when id missing', () {
        final json = {
          'name': 'OpenAI',
        };
        final provider = Provider.fromJson(json);
        expect(provider.id, 'OpenAI');
        expect(provider.name, 'OpenAI');
      });

      test('falls back to id when name missing', () {
        final json = {
          'id': 'openai',
        };
        final provider = Provider.fromJson(json);
        expect(provider.id, 'openai');
        expect(provider.name, 'openai');
      });

      test('handles empty models', () {
        final json = {
          'id': 'openai',
          'name': 'OpenAI',
          'models': [],
        };
        final provider = Provider.fromJson(json);
        expect(provider.models, isEmpty);
      });

      test('handles null models', () {
        final json = {
          'id': 'openai',
          'name': 'OpenAI',
          'models': null,
        };
        final provider = Provider.fromJson(json);
        expect(provider.models, isEmpty);
      });

      test('uses model ID as fallback when name missing in map format', () {
        final json = {
          'id': 'openai',
          'name': 'OpenAI',
          'models': {
            'gpt-4': <String, dynamic>{},
          },
        };
        final provider = Provider.fromJson(json);
        expect(provider.models[0].name, 'gpt-4');
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final provider = Provider(
          id: 'openai',
          name: 'OpenAI',
          models: [
            ProviderModel(id: 'gpt-4', name: 'GPT-4'),
          ],
          configured: true,
        );
        final json = provider.toJson();

        expect(json['id'], 'openai');
        expect(json['name'], 'OpenAI');
        expect(json['configured'], true);
        expect(json['models'], isA<List>());
        expect((json['models'] as List).length, 1);
      });

      test('serializes models correctly', () {
        final provider = Provider(
          id: 'openai',
          name: 'OpenAI',
          models: [
            ProviderModel(
              id: 'gpt-4',
              name: 'GPT-4',
              costInput: 0.03,
            ),
          ],
        );
        final json = provider.toJson();
        final modelsJson = json['models'] as List;

        expect(modelsJson[0]['id'], 'gpt-4');
        expect(modelsJson[0]['name'], 'GPT-4');
        expect(modelsJson[0]['cost']['input'], 0.03);
      });

      test('produces valid JSON', () {
        final provider = Provider(
          id: 'openai',
          name: 'OpenAI',
          configured: true,
        );
        final jsonString = jsonEncode(provider.toJson());
        expect(() => jsonDecode(jsonString), returnsNormally);
      });
    });
  });

  group('ProvidersResponse', () {
    group('fromJson', () {
      test('parses providers list', () {
        final json = {
          'providers': [
            {'id': 'openai', 'name': 'OpenAI'},
            {'id': 'anthropic', 'name': 'Anthropic'},
          ],
        };
        final response = ProvidersResponse.fromJson(json);
        expect(response.providers.length, 2);
        expect(response.providers[0].id, 'openai');
        expect(response.providers[1].id, 'anthropic');
      });

      test('parses defaults map', () {
        final json = {
          'providers': [],
          'default': {
            'provider': 'openai',
            'model': 'gpt-4',
          },
        };
        final response = ProvidersResponse.fromJson(json);
        expect(response.defaults['provider'], 'openai');
        expect(response.defaults['model'], 'gpt-4');
      });

      test('handles empty providers list', () {
        final json = <String, dynamic>{};
        final response = ProvidersResponse.fromJson(json);
        expect(response.providers, isEmpty);
        expect(response.defaults, isEmpty);
      });

      test('handles missing providers key', () {
        final json = {'default': {'provider': 'openai'}};
        final response = ProvidersResponse.fromJson(json);
        expect(response.providers, isEmpty);
        expect(response.defaults['provider'], 'openai');
      });

      test('handles null providers', () {
        final json = {
          'providers': <dynamic>[],
          'default': <String, dynamic>{},
        };
        final response = ProvidersResponse.fromJson(json);
        expect(response.providers, isEmpty);
      });

      test('converts default values to strings', () {
        final json = {
          'providers': [],
          'default': {
            'provider': 'openai',
            'model': 123,
          },
        };
        final response = ProvidersResponse.fromJson(json);
        expect(response.defaults['model'], '123');
      });
    });
  });
}
