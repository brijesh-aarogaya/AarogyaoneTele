import 'package:flutter_test/flutter_test.dart';
import 'package:aarogyaone_tele/aarogyaone_tele.dart';
import 'package:aarogyaone_tele/aarogyaone_tele_platform_interface.dart';
import 'package:aarogyaone_tele/aarogyaone_tele_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAarogyaoneTelePlatform
    with MockPlatformInterfaceMixin
    implements AarogyaoneTelePlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final AarogyaoneTelePlatform initialPlatform = AarogyaoneTelePlatform.instance;

  test('$MethodChannelAarogyaoneTele is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAarogyaoneTele>());
  });

  test('getPlatformVersion', () async {
    AarogyaoneTele aarogyaoneTelePlugin = AarogyaoneTele();
    MockAarogyaoneTelePlatform fakePlatform = MockAarogyaoneTelePlatform();
    AarogyaoneTelePlatform.instance = fakePlatform;

    expect(await aarogyaoneTelePlugin.getPlatformVersion(), '42');
  });
}
