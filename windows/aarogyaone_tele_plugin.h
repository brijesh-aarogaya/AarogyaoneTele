#ifndef FLUTTER_PLUGIN_AAROGYAONE_TELE_PLUGIN_H_
#define FLUTTER_PLUGIN_AAROGYAONE_TELE_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace aarogyaone_tele {

class AarogyaoneTelePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  AarogyaoneTelePlugin();

  virtual ~AarogyaoneTelePlugin();

  // Disallow copy and assign.
  AarogyaoneTelePlugin(const AarogyaoneTelePlugin&) = delete;
  AarogyaoneTelePlugin& operator=(const AarogyaoneTelePlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace aarogyaone_tele

#endif  // FLUTTER_PLUGIN_AAROGYAONE_TELE_PLUGIN_H_
