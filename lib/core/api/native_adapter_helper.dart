import 'package:dio/dio.dart';
import 'package:native_dio_adapter/native_dio_adapter.dart';

HttpClientAdapter createNativeAdapter() => NativeAdapter();
