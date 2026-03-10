import 'package:flutter/foundation.dart';

import '../../platform_io.dart'
    if (dart.library.js_interop) '../../platform_stub.dart';

class CertificateStatus {
  const CertificateStatus({
    required this.supported,
    required this.hasUserCertificates,
    required this.message,
  });

  final bool supported;
  final bool hasUserCertificates;
  final String message;
}

class CertificateProvider {
  const CertificateProvider();

  Future<CertificateStatus> getStatus() async {
    if (!kIsWeb && isAndroid) {
      return const CertificateStatus(
        supported: true,
        hasUserCertificates: true,
        message:
            'Android trusts user-installed CA certificates via the system '
            'trust store and network security config.',
      );
    }

    return const CertificateStatus(
      supported: false,
      hasUserCertificates: false,
      message: 'User-installed CA certificates are only surfaced on Android.',
    );
  }
}
