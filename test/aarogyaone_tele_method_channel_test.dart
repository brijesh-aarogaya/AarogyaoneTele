import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aarogyaone_tele/aarogyaone_tele_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelAarogyaoneTele platform = MethodChannelAarogyaoneTele();
  const MethodChannel channel = MethodChannel('aarogyaone_tele');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
