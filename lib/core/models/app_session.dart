class AppSession {
  const AppSession({
    required this.serverUrl,
    required this.username,
    required this.token,
  });

  final String serverUrl;
  final String username;
  final String token;

  AppSession copyWith({String? serverUrl, String? username, String? token}) {
    return AppSession(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      token: token ?? this.token,
    );
  }
}
