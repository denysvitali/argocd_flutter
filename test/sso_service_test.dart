import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:argocd_flutter/core/services/argocd_api.dart';
import 'package:argocd_flutter/core/services/sso_service_native.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _OidcAdapter implements HttpClientAdapter {
  Map<String, dynamic>? tokenRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    Object body;
    switch (options.uri.path) {
      case '/api/v1/settings':
        body = <String, dynamic>{
          'oidcConfig': <String, dynamic>{
            'issuer': 'https://issuer.example',
            'clientID': 'web',
            'cliClientID': 'cli',
          },
        };
      case '/.well-known/openid-configuration':
        body = <String, dynamic>{
          'issuer': 'https://issuer.example',
          'authorization_endpoint': 'https://issuer.example/authorize',
          'token_endpoint': 'https://issuer.example/token',
          'response_types_supported': <String>['code'],
        };
      case '/token':
        tokenRequest = Map<String, dynamic>.from(options.data as Map);
        body = <String, String>{'id_token': 'server-validated-token'};
      case '/api/v1/session/userinfo':
        expect(
          options.headers['Authorization'],
          'Bearer server-validated-token',
        );
        body = <String, dynamic>{'loggedIn': true, 'username': 'alice'};
      default:
        throw StateError('Unexpected request ${options.uri.path}');
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  test(
    'code exchange uses CLI client, state and S256 PKCE; invalid state is ignored',
    () async {
      final adapter = _OidcAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      late HttpServer listener;
      late String challenge;
      final session = await performSsoSignIn(
        'https://argo.example',
        isAndroid: true,
        httpClient: dio,
        bindCallback: () async {
          listener = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          return listener;
        },
        openBrowser: (uri) async {
          final query = uri.queryParameters;
          expect(query['client_id'], 'cli');
          expect(query['redirect_uri'], 'http://localhost:8085/auth/callback');
          expect(query['code_challenge_method'], 'S256');
          challenge = query['code_challenge']!;
          final client = HttpOverrides.runWithHttpOverrides(
            HttpClient.new,
            _RealHttpOverrides(),
          );
          try {
            for (final state in <String>['wrong', query['state']!]) {
              final request = await client.getUrl(
                Uri.http(
                  '127.0.0.1:${listener.port}',
                  '/auth/callback',
                  <String, String>{'code': 'auth-code', 'state': state},
                ),
              );
              final response = await request.close();
              expect(response.statusCode, state == 'wrong' ? 400 : 200);
              await response.drain<void>();
            }
          } finally {
            client.close(force: true);
          }
        },
      );
      expect(session.username, 'alice');
      expect(session.token, 'server-validated-token');
      final exchange = adapter.tokenRequest!;
      expect(exchange['code'], 'auth-code');
      expect(exchange['client_id'], 'cli');
      final verifier = exchange['code_verifier']! as String;
      expect(
        base64Url
            .encode(sha256.convert(ascii.encode(verifier)).bytes)
            .replaceAll('=', ''),
        challenge,
      );
    },
  );

  test(
    'browser dismissal times out and closes the loopback listener',
    () async {
      final dio = Dio()..httpClientAdapter = _OidcAdapter();
      late HttpServer listener;
      late int port;
      await expectLater(
        performSsoSignIn(
          'https://argo.example',
          isAndroid: true,
          httpClient: dio,
          timeout: const Duration(milliseconds: 20),
          bindCallback: () async {
            listener = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
            port = listener.port;
            return listener;
          },
          openBrowser: (_) async {},
        ),
        throwsA(
          isA<ArgoCdException>().having(
            (error) => error.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
      final reopened = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        port,
      );
      await reopened.close(force: true);
    },
  );
}
