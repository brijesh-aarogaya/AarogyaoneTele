import 'package:aarogyaone_tele/enum.dart';
import 'package:aarogyaone_tele/sdks/agora_sdk_page.dart';
import 'package:flutter/material.dart';

import 'aarogyaone_tele_platform_interface.dart';

class AarogyaoneTele {
  Future<String?> getPlatformVersion() {
    return AarogyaoneTelePlatform.instance.getPlatformVersion();
  }

  Future joinSDK({
    required BuildContext context,
    required TeleConsultationSdkEnum sdkType,
    required AgoraConfig config,
    required Future<bool> Function()? onCallEnd,
  }) async {
    if (sdkType == TeleConsultationSdkEnum.agora) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            return AgoraVideoCallScreen(config: config, onCallEnd: onCallEnd);
          },
        ),
      );
    }
  }
}
