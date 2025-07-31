import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'aarogyaone_tele_method_channel.dart';

abstract class AarogyaoneTelePlatform extends PlatformInterface {
  /// Constructs a AarogyaoneTelePlatform.
  AarogyaoneTelePlatform() : super(token: _token);

  static final Object _token = Object();

  static AarogyaoneTelePlatform _instance = MethodChannelAarogyaoneTele();

  /// The default instance of [AarogyaoneTelePlatform] to use.
  ///
  /// Defaults to [MethodChannelAarogyaoneTele].
  static AarogyaoneTelePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AarogyaoneTelePlatform] when
  /// they register themselves.
  static set instance(AarogyaoneTelePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
