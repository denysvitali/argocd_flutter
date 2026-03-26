import 'dart:convert';

import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:dio/dio.dart';
import 'package:sentry_dio/sentry_dio.dart';

import '../api/native_adapter_helper.dart'
    if (dart.library.js_interop) '../api/native_adapter_helper_web.dart';
import '../utils/json_parsing.dart';

abstract class ArgoCdApi {
  Future<void> verifyServer(String serverUrl);
  Future<AppSession> signIn({
    required String serverUrl,
    required String username,
    required String password,
  });
  Future<List<ArgoApplication>> fetchApplications(AppSession session);
  Future<List<ArgoProject>> fetchProjects(AppSession session);
  Future<ArgoApplication> fetchApplication(
    AppSession session,
    String applicationName, {
    bool refresh = false,
  });
  Future<ArgoProject> fetchProject(AppSession session, String projectName);
  Future<List<ArgoResourceNode>> fetchResourceTree(
    AppSession session,
    String applicationName,
  );
  Future<void> syncApplication(AppSession session, String applicationName);
  Future<void> rollbackApplication(
    AppSession session,
    String applicationName,
    int historyId,
  );
  Future<void> deleteApplication(
    AppSession session,
    String applicationName, {
    bool cascade = true,
  });
  Future<void> deleteResource(
    AppSession session, {
    required String applicationName,
    required String namespace,
    required String resourceName,
    required String kind,
    required String group,
    required String version,
    bool force = false,
  });
  Future<String> fetchResourceLogs(
    AppSession session, {
    required String applicationName,
    required String namespace,
    required String podName,
    String? containerName,
    int tailLines = 500,
  });
  Future<String> fetchResourceManifest(
    AppSession session, {
    required String applicationName,
    required String namespace,
    required String resourceName,
    required String kind,
    required String group,
    required String version,
  });
  Future<List<ManagedResource>> fetchManagedResources(
    AppSession session,
    String applicationName,
  );
}

class ManagedResource {
  const ManagedResource({
    required this.kind,
    required this.name,
    required this.namespace,
    required this.group,
    required this.targetState,
    required this.liveState,
  });

  final String kind;
  final String name;
  final String namespace;
  final String group;
  final String? targetState;
  final String? liveState;

  bool get hasDiff =>
      targetState != null && liveState != null && targetState != liveState;
}

class NetworkArgoCdApi implements ArgoCdApi {
  @override
  Future<void> verifyServer(String serverUrl) async {
    final dio = _createDio(serverUrl);
    try {
      final response = await dio.get<dynamic>('/api/version');
      final status = response.statusCode ?? 0;
      if (status >= 500 || status == 0) {
        throw ArgoCdException(
          'The ArgoCD server did not respond successfully.',
        );
      }
    } on DioException catch (error) {
      throw ArgoCdException(_formatDioError(error));
    } finally {
      dio.close(force: true);
    }
  }

  @override
  Future<AppSession> signIn({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final dio = _createDio(serverUrl);
    try {
      final response = await dio.post<dynamic>(
        '/api/v1/session',
        data: <String, String>{'username': username, 'password': password},
      );

      final body = parseMap(response.data);
      final token = body['token']?.toString();
      if (response.statusCode != 200 || token == null || token.isEmpty) {
        throw ArgoCdException(
          _extractErrorMessage(body) ?? 'Authentication failed.',
        );
      }

      final resolvedUsername = await _fetchUsername(
        serverUrl: serverUrl,
        token: token,
        fallback: username,
      );

      return AppSession(
        serverUrl: _normalizedServerUrl(serverUrl),
        username: resolvedUsername,
        token: token,
      );
    } on DioException catch (error) {
      throw ArgoCdException(_formatDioError(error));
    } finally {
      dio.close(force: true);
    }
  }

  @override
  Future<List<ArgoApplication>> fetchApplications(AppSession session) async {
    final dio = _createDio(session.serverUrl, token: session.token);
    try {
      final response = await dio.get<dynamic>('/api/v1/applications');
      _throwIfRequestFailed(response);
      final body = parseMap(response.data);
      final items = body['items'] as List<dynamic>? ?? const <dynamic>[];
      return items
          .map((dynamic item) => ArgoApplication.fromJson(parseMap(item)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw ArgoCdException(_formatDioError(error));
    } finally {
      dio.close(force: true);
    }
  }

  @override
  Future<List<ArgoProject>> fetchProjects(AppSession session) async {
    final dio = _createDio(session.serverUrl, token: session.token);
    try {
      final response = await dio.get<dynamic>('/api/v1/projects');
      _throwIfRequestFailed(response);
      final body = parseMap(response.data);
      final items = body['items'] as List<dynamic>? ?? const <dynamic>[];
      return items
          .map((dynamic item) => ArgoProject.fromJson(parseMap(item)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw ArgoCdException(_formatDioError(error));
    } finally {
      dio.close(force: true);
    }
  }

  @override
  Future<ArgoApplication> fetchApplication(
    AppSession session,
    String applicationName, {
    bool refresh = false,
  }) async {
    final dio = _createDio(session.serverUrl, token: session.token);
    try {
      final response = await dio.get<dynamic>(
        '/api/v1/applications/${Uri.encodeComponent(applicationName)}',
        queryParameters: refresh
            ? const <String, String>{'refresh': 'normal'}
            : null,
      );
      _throwIfRequestFailed(response);
      return ArgoApplication.fromJson(parseMap(response.data));
    } on DioException catch (error) {
      throw ArgoCdException(_formatDioError(error));
    } finally {
      dio.close(force: true);
    }
  }

  @override
  Future<ArgoProject> fetchProject(
    AppSession session,
    String projectName,
  ) async {
    final dio = _createDio(session.serverUrl, token: session.token);
    try {
      final response = await dio.get<dynamic>(
        '/api/v1/projects/${Uri.encodeComponent(projectName)}',
      );
      _throwIfRequestFailed(response);
      return ArgoProject.fromJson(parseMap(response.data));
    } on DioException catch (error) {
      throw ArgoCdException(_formatDioError(error));
    } finally {
      dio.close(force: true);
    }
  }

  @override
  Future<List<ArgoResourceNode>> fetchResourceTree(
    AppSession session,
    String applicationName,
  ) async {
    final dio = _createDio(session.serverUrl, token: session.token);
    try {
      final response = await dio.get<dynamic>(
        '/api/v1/applications/${Uri.encodeComponent(applicationName)}/resource-tree',
      );
      _throwIfRequestFailed(response);
      final body = parseMap(response.data);
      return parseList(body['nodes'])
          .map((dynamic item) => ArgoResourceNode.fromJson(parseMap(item)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw ArgoCdException(_formatDioError(error));
    } finally {
      dio.close(force: true);
    }
  }

  @override
  Future<void> syncApplication(
    AppSession session,
    String applicationName,
  ) async {
    final dio = _createDio(session.serverUrl, token: session.token);
    try {
      final response = await dio.post<dynamic>(
        '/api/v1/applications/${Uri.encodeComponent(applicationName)}/sync',
        data: const <String, dynamic>{},
      );
      _throwIfRequestFailed(response);
    } on DioException catch (error) {
      throw ArgoCdException(_formatDioError(error));
    } finally {
      dio.close(force: true);
    }
  }

  @override
  Future<void> rollbackApplication(
    AppSession session,
    String applicationName,
    int historyId,
  ) async {
    final dio = _createDio(session.serverUrl, token: session.token);
    try {
      final response = await dio.put<dynamic>(
        '/api/v1/applications/${Uri.encodeComponent(applicationName)}/rollback',
        data: <String, dynamic>{'id': historyId, 'prune': true},
      );
      _throwIfRequestFailed(response);
    } on DioException catch (error) {
      throw ArgoCdException(_formatDioError(error));
    } finally {
      dio.close(force: true);
    }
  }

  @override
  Future<void> deleteApplication(
    AppSession session,
    String applicationName, {
    bool cascade = true,
  }) async {
    final dio = _createDio(session.serverUrl, token: session.token);
    try {
      final response = await dio.delete<dynamic>(
        '/api/v1/applications/${Uri.encodeComponent(applicationName)}',
        queryParameters: <String, String>{'cascade': '$cascade'},
      );
      _throwIfRequestFailed(response);
    } on DioException catch (error) {
      throw ArgoCdException(_formatDioError(error));
    } finally {
      dio.close(force: true);
    }
  }

  @override
  Future<void> deleteResource(
    AppSession session, {
    required String applicationName,
    required String namespace,
    required String resourceName,
    required String kind,
    required String group,
    required String version,
    bool force = false,
  }) async {
    final dio = _createDio(session.serverUrl, token: session.token);
    try {
      final response = await dio.delete<dynamic>(
        '/api/v1/applications/${Uri.encodeComponent(applicationName)}/resource',
        queryParameters: <String, dynamic>{
          'namespace': namespace,
          'resourceName': resourceName,
          'kind': kind,
          'group': group,
          'version': version,
          'force': force,
        },
      );
      _throwIfRequestFailed(response);
    } on DioException catch (error) {
      throw ArgoCdException(_formatDioError(error));
    } finally {
      dio.close(force: true);
    }
  }

  @override
  Future<String> fetchResourceLogs(
    AppSession session, {
    required String applicationName,
    required String namespace,
    required String podName,
    String? containerName,
    int tailLines = 500,
  }) async {
    final dio = _createDio(session.serverUrl, token: session.token);
    try {
      final response = await dio.get<dynamic>(
        '/api/v1/applications/${Uri.encodeComponent(applicationName)}/logs',
        queryParameters: <String, dynamic>{
          'namespace': namespace,
          'podName': podName,
          'tailLines': tailLines,
          'follow': false,
          if (containerName != null && containerName.trim().isNotEmpty)
            'container': containerName,
        },
        options: Options(responseType: ResponseType.plain),
      );
      _throwIfRequestFailed(response);
      return _extractLogContent(response.data);
    } on DioException catch (error) {
      throw ArgoCdException(_formatDioError(error));
    } on FormatException catch (error) {
      throw ArgoCdException('Failed to parse log output: ${error.message}');
    } catch (error) {
      if (error is ArgoCdException) {
        rethrow;
      }
      throw ArgoCdException('Failed to load resource logs.');
    } finally {
      dio.close(force: true);
    }
  }

  @override
  Future<String> fetchResourceManifest(
    AppSession session, {
    required String applicationName,
    required String namespace,
    required String resourceName,
    required String kind,
    required String group,
    required String version,
  }) async {
    final dio = _createDio(session.serverUrl, token: session.token);
    try {
      final encodedApp = Uri.encodeComponent(applicationName);
      final queryParams = <String, dynamic>{
        'namespace': namespace,
        'name': resourceName,
        'kind': kind,
        'group': group,
        'version': version,
      };

      // Try managed-resources endpoint first — it returns both targetState
      // and liveState which enables the diff view for out-of-sync resources.
      final managedResponse = await dio.get<dynamic>(
        '/api/v1/applications/$encodedApp/managed-resources',
        queryParameters: queryParams,
      );

      if ((managedResponse.statusCode ?? 500) < 400) {
        final body = parseMap(managedResponse.data);
        final items = parseList(body['items']);

        for (final dynamic item in items) {
          final map = parseMap(item);
          if (map['name']?.toString() == resourceName &&
              map['kind']?.toString() == kind &&
              map['namespace']?.toString() == namespace) {
            final liveState = map['liveState'];
            final targetState = map['targetState'];
            if (liveState != null) {
              final envelope = <String, dynamic>{
                'manifest': liveState,
                'targetState': targetState,
                'liveState': liveState,
              };
              return jsonEncode(envelope);
            }
          }
        }
      }

      // Fall back to the resource endpoint (no diff data, but manifest works).
      final response = await dio.get<dynamic>(
        '/api/v1/applications/$encodedApp/resource',
        queryParameters: <String, dynamic>{
          'namespace': namespace,
          'resourceName': resourceName,
          'kind': kind,
          'group': group,
          'version': version,
        },
      );
      _throwIfRequestFailed(response);
      final data = response.data;
      if (data is String) {
        return data;
      }
      return jsonEncode(data);
    } on DioException catch (error) {
      throw ArgoCdException(_formatDioError(error));
    } catch (error) {
      if (error is ArgoCdException) {
        rethrow;
      }
      throw const ArgoCdException('Failed to load resource manifest.');
    } finally {
      dio.close(force: true);
    }
  }

  @override
  Future<List<ManagedResource>> fetchManagedResources(
    AppSession session,
    String applicationName,
  ) async {
    final dio = _createDio(session.serverUrl, token: session.token);
    try {
      final encodedApp = Uri.encodeComponent(applicationName);
      final response = await dio.get<dynamic>(
        '/api/v1/applications/$encodedApp/managed-resources',
      );
      _throwIfRequestFailed(response);
      final body = parseMap(response.data);
      final items = parseList(body['items']);
      return items.map((dynamic item) {
        final map = parseMap(item);
        return ManagedResource(
          kind: parseString(map['kind'], fallback: 'Resource'),
          name: parseString(map['name'], fallback: 'Unknown'),
          namespace: parseString(map['namespace'], fallback: '-'),
          group: parseString(map['group'], fallback: ''),
          targetState: map['targetState'] as String?,
          liveState: map['liveState'] as String?,
        );
      }).toList();
    } on DioException catch (error) {
      throw ArgoCdException(_formatDioError(error));
    } catch (error) {
      if (error is ArgoCdException) {
        rethrow;
      }
      throw const ArgoCdException('Failed to load managed resources.');
    } finally {
      dio.close(force: true);
    }
  }

  Future<String> _fetchUsername({
    required String serverUrl,
    required String token,
    required String fallback,
  }) async {
    final dio = _createDio(serverUrl, token: token);
    try {
      final response = await dio.get<dynamic>('/api/v1/account/userinfo');
      if ((response.statusCode ?? 500) >= 400) {
        return fallback;
      }

      final body = parseMap(response.data);
      return body['username']?.toString() ?? fallback;
    } catch (_) {
      return fallback;
    } finally {
      dio.close(force: true);
    }
  }

  Dio _createDio(String serverUrl, {String? token}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: _normalizedServerUrl(serverUrl),
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 20),
        validateStatus: (int? _) => true,
        contentType: 'application/json',
      ),
    );

    dio.httpClientAdapter = createNativeAdapter();
    dio.addSentry();
    dio.options.headers['User-Agent'] = 'ArgoCdFlutter/1.0';
    if (token != null && token.isNotEmpty) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }

    return dio;
  }

  void _throwIfRequestFailed(Response<dynamic> response) {
    final status = response.statusCode ?? 500;
    if (status >= 400) {
      final body = parseMap(response.data);
      throw ArgoCdException(
        _extractErrorMessage(body) ?? 'Request failed with HTTP $status.',
      );
    }
  }
}

class ArgoCdException implements Exception {
  const ArgoCdException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _normalizedServerUrl(String serverUrl) {
  return serverUrl.trim().replaceFirst(RegExp(r'/$'), '');
}

String _formatDioError(DioException error) {
  final responseBody = parseMap(error.response?.data);
  final apiMessage = _extractErrorMessage(responseBody);
  if (apiMessage != null) {
    return apiMessage;
  }

  final message = error.message?.trim();
  if (message != null && message.isNotEmpty) {
    return message;
  }

  return 'Network request failed.';
}

String? _extractErrorMessage(Map<String, dynamic> body) {
  final fields = <String?>[
    body['error']?.toString(),
    body['message']?.toString(),
  ];

  for (final field in fields) {
    if (field != null && field.trim().isNotEmpty) {
      return field;
    }
  }

  return null;
}

String _extractLogContent(dynamic data) {
  if (data is String) {
    final lines = data
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .map((String line) => _extractLogLineContent(jsonDecode(line)))
        .where((String line) => line.isNotEmpty)
        .toList(growable: false);
    return lines.join('\n');
  }

  if (data is List) {
    final lines = data
        .map((dynamic item) => _extractLogLineContent(item))
        .where((String line) => line.isNotEmpty)
        .toList(growable: false);
    return lines.join('\n');
  }

  final content = _extractLogLineContent(data);
  if (content.isNotEmpty) {
    return content;
  }

  throw const FormatException('Unexpected response format.');
}

String _extractLogLineContent(dynamic item) {
  final result = parseMap(parseMap(item)['result']);
  final content = result['content'];
  if (content is String) {
    return content;
  }
  if (content != null) {
    return content.toString();
  }
  return '';
}
