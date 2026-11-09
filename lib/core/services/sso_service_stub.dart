import '../models/app_session.dart';
import 'argocd_api.dart';

Future<AppSession> signInWithSso(String serverUrl) async {
  throw const ArgoCdException('SSO sign-in is currently supported on Android.');
}
