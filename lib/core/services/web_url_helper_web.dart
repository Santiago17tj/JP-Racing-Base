import 'dart:html' as html;
import 'package:flutter_web_plugins/url_strategy.dart';

class WebUrlHelper {
  static String getHash() {
    return html.window.location.hash;
  }

  static void clearHash() {
    try {
      html.window.history.replaceState(null, '', '/');
    } catch (_) {}
  }

  static void configureUrlStrategy() {
    usePathUrlStrategy();
  }
}
