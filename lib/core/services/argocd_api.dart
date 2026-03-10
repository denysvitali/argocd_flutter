import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:dio/dio.dart';

import '../api/native_adapter_helper.dart'
    if (dart.library.js_interop) '../api/native_adapter_helper_web.dart';

abstract class ArgoCdApi {
  Future<void> verifyServer(String serverUrl);
  Future<AppSession> signIn({
    required String serverUrl,
    required String username,
    required String password,
  });
  Future<List<ArgoApplication>> fetchApplications(AppSession session);
  Future<ArgoApplication> fetchApplication(
    AppSession session,
    String applicationName, {
    bool refresh = false,
  });
  Future<void> syncApplication(AppSession session, String applicationName);
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

      final body = _map(response.data);
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
      final body = _map(response.data);
      final items = body['items'] as List<dynamic>? ?? const <dynamic>[];
      return items
          .map((dynamic item) => ArgoApplication.fromJson(_map(item)))
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
      return ArgoApplication.fromJson(_map(response.data));
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

      final body = _map(response.data);
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
    dio.options.headers['User-Agent'] = 'ArgoCdFlutter/1.0';
    if (token != null && token.isNotEmpty) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }

    return dio;
  }

  void _throwIfRequestFailed(Response<dynamic> response) {
    final status = response.statusCode ?? 500;
    if (status >= 400) {
      final body = _map(response.data);
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
  final responseBody = _map(error.response?.data);
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

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic val) => MapEntry(key.toString(), val),
    );
  }
  return const <String, dynamic>{};
}
