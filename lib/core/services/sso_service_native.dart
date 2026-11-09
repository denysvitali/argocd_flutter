import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../api/native_adapter_helper.dart';
import '../models/app_session.dart';
import '../utils/json_parsing.dart';
import 'argocd_api.dart';

const _browser = MethodChannel('it.denv.argocd_flutter/sso');
bool _signingIn = false;

/// Uses the same public OIDC client and loopback redirect as `argocd login --sso`.
Future<AppSession> signInWithSso(String serverUrl) => performSsoSignIn(
  serverUrl,
  isAndroid: Platform.isAndroid,
  openBrowser: (uri) =>
      _browser.invokeMethod<void>('openBrowser', uri.toString()),
);

// Explicit dependencies allow the real protocol to be exercised without Android.
Future<AppSession> performSsoSignIn(
  String serverUrl, {
  required bool isAndroid,
  required Future<void> Function(Uri) openBrowser,
  Dio? httpClient,
  Future<HttpServer> Function()? bindCallback,
  Duration timeout = const Duration(minutes: 3),
}) async {
  if (!isAndroid) {
    throw const ArgoCdException(
      'SSO sign-in is currently supported on Android.',
    );
  }
  if (_signingIn) {
    throw const ArgoCdException('An SSO sign-in is already in progress.');
  }
  final base = Uri.tryParse(serverUrl.trim().replaceFirst(RegExp(r'/+$'), ''));
  if (base == null ||
      base.scheme != 'https' ||
      base.host.isEmpty ||
      base.userInfo.isNotEmpty ||
      base.hasQuery ||
      base.hasFragment) {
    throw const ArgoCdException('SSO requires a valid HTTPS server URL.');
  }
  _signingIn = true;
  final dio =
      httpClient ??
      Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 20),
          followRedirects: false,
        ),
      );
  if (httpClient == null) dio.httpClientAdapter = createNativeAdapter();
  HttpServer? listener;
  Timer? timeoutTimer;
  try {
    final settings = parseMap(
      (await dio.get<dynamic>('$base/api/v1/settings')).data,
    );
    final oidc = parseMap(settings['oidcConfig']);
    final dex = parseMap(settings['dexConfig']);
    final direct = parseString(oidc['issuer'], fallback: '').isNotEmpty;
    if (!direct && parseList(dex['connectors']).isEmpty) {
      throw const ArgoCdException('This server is not configured for SSO.');
    }
    final issuer = direct
        ? parseString(oidc['issuer'])
        : '${parseString(settings['url'], fallback: '$base').replaceFirst(RegExp(r'/+$'), '')}/api/dex';
    final issuerUri = _secureEndpoint(issuer);
    final clientId = direct
        ? parseString(oidc['cliClientID'], fallback: '').isNotEmpty
              ? parseString(oidc['cliClientID'])
              : parseString(oidc['clientID'], fallback: '')
        : 'argo-cd-cli';
    if (clientId.isEmpty) {
      throw const ArgoCdException(
        'The server has no public SSO client configured.',
      );
    }
    final discovery = parseMap(
      (await dio.get<dynamic>(
        '${issuerUri.toString().replaceFirst(RegExp(r'/+$'), '')}/.well-known/openid-configuration',
      )).data,
    );
    if (discovery['issuer'] != issuer) {
      throw const ArgoCdException(
        'The SSO provider returned an unexpected issuer.',
      );
    }
    final authorization = _secureEndpoint(
      parseString(discovery['authorization_endpoint'], fallback: ''),
    );
    final tokenEndpoint = _secureEndpoint(
      parseString(discovery['token_endpoint'], fallback: ''),
    );
    if (!parseList(discovery['response_types_supported']).contains('code')) {
      throw const ArgoCdException(
        'The SSO provider must support authorization code sign-in.',
      );
    }
    final requestedScopes = parseList(
      oidc['scopes'],
    ).whereType<String>().toList();
    final scopes = direct && requestedScopes.isNotEmpty
        ? requestedScopes
        : <String>['openid', 'profile', 'email', 'groups'];
    if (!direct) scopes.add('federated:id');
    final state = _randomString();
    final verifier = _randomString();
    final challenge = base64Url
        .encode(sha256.convert(ascii.encode(verifier)).bytes)
        .replaceAll('=', '');
    // Dex registers this exact CLI callback. Bind only loopback, never all interfaces.
    listener =
        await (bindCallback?.call() ??
            HttpServer.bind(InternetAddress.loopbackIPv4, 8085));
    const redirect = 'http://localhost:8085/auth/callback';
    final callback = Completer<String>();
    listener.listen(
      (request) async {
        request.response.headers.set('Cache-Control', 'no-store');
        request.response.headers.set('Referrer-Policy', 'no-referrer');
        final query = request.uri.queryParameters;
        if (request.method != 'GET' ||
            request.uri.path != '/auth/callback' ||
            query['state'] != state ||
            callback.isCompleted) {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.write('Invalid sign-in callback.');
        } else if (query.containsKey('error')) {
          request.response.write('Sign-in was cancelled. Return to ArgoCD.');
          callback.completeError(
            const ArgoCdException('SSO sign-in was cancelled or denied.'),
          );
        } else if ((query['code'] ?? '').isEmpty) {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.write('Missing authorization code.');
        } else {
          request.response.write('Sign-in received. You can return to ArgoCD.');
          callback.complete(query['code']!);
        }
        await request.response.close();
      },
      onError: (Object error) {
        if (!callback.isCompleted) callback.completeError(error);
      },
    );
    final authorizationUrl = authorization.replace(
      queryParameters: <String, String>{
        ...authorization.queryParameters,
        'client_id': clientId,
        'redirect_uri': redirect,
        'response_type': 'code',
        'scope': scopes.join(' '),
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        if (parseString(dex['dexAuthConnectorID'], fallback: '').isNotEmpty)
          'connector_id': parseString(dex['dexAuthConnectorID']),
        if (parseMap(oidc['idTokenClaims']).isNotEmpty)
          'claims': jsonEncode(<String, dynamic>{
            'id_token': oidc['idTokenClaims'],
          }),
      },
    );
    // Attach the timeout/error listener before opening the browser.
    timeoutTimer = Timer(timeout, () {
      if (!callback.isCompleted) {
        callback.completeError(
          const ArgoCdException('SSO sign-in timed out. Please try again.'),
        );
      }
    });
    final results = await Future.wait<Object?>([
      callback.future,
      openBrowser(authorizationUrl),
    ], eagerError: true);
    final code = results.first! as String;
    final tokenResponse = parseMap(
      (await dio.post<dynamic>(
        tokenEndpoint.toString(),
        data: <String, String>{
          'grant_type': 'authorization_code',
          'client_id': clientId,
          'redirect_uri': redirect,
          'code': code,
          'code_verifier': verifier,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      )).data,
    );
    final token = parseString(tokenResponse['id_token'], fallback: '');
    if (token.isEmpty) {
      throw const ArgoCdException(
        'The SSO provider did not return an ID token.',
      );
    }
    // ArgoCD validates the token's signature, issuer, audience and expiry.
    final user = parseMap(
      (await dio.get<dynamic>(
        '$base/api/v1/session/userinfo',
        options: Options(
          headers: <String, String>{'Authorization': 'Bearer $token'},
        ),
      )).data,
    );
    if (user['loggedIn'] != true) {
      throw const ArgoCdException(
        'The ArgoCD server rejected the SSO session.',
      );
    }
    return AppSession(
      serverUrl: '$base',
      username: parseString(user['username'], fallback: 'SSO user'),
      token: token,
    );
  } on ArgoCdException {
    rethrow;
  } on SocketException {
    throw const ArgoCdException(
      'Could not open the local SSO callback on port 8085. Close other sign-ins and try again.',
    );
  } on PlatformException {
    throw const ArgoCdException('Could not open a browser for SSO sign-in.');
  } on MissingPluginException {
    throw const ArgoCdException('SSO sign-in is unavailable on this platform.');
  } on DioException {
    throw const ArgoCdException(
      'SSO could not contact the server or provider. Check the server URL and CLI client configuration.',
    );
  } catch (_) {
    throw const ArgoCdException('SSO sign-in could not be completed.');
  } finally {
    timeoutTimer?.cancel();
    await listener?.close(force: true);
    dio.close(force: true);
    _signingIn = false;
  }
}

Uri _secureEndpoint(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    throw const ArgoCdException(
      'The SSO provider must use valid HTTPS endpoints.',
    );
  }
  return uri;
}

String _randomString() {
  final random = Random.secure();
  return base64Url
      .encode(List<int>.generate(32, (_) => random.nextInt(256)))
      .replaceAll('=', '');
}
