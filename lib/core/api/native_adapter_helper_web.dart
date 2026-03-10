import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

HttpClientAdapter createNativeAdapter() => BrowserHttpClientAdapter();
