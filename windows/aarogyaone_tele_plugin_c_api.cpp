#include "include/aarogyaone_tele/aarogyaone_tele_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "aarogyaone_tele_plugin.h"

void AarogyaoneTelePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  aarogyaone_tele::AarogyaoneTelePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
