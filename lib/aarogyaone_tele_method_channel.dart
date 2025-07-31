import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'aarogyaone_tele_platform_interface.dart';

/// An implementation of [AarogyaoneTelePlatform] that uses method channels.
class MethodChannelAarogyaoneTele extends AarogyaoneTelePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('aarogyaone_tele');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
