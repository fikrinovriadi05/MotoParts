import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi_web;

/// Web: tombol resmi Google Identity Services. Di web, `authenticate()` tidak
/// didukung; hasil masuk datang lewat `GoogleSignIn.authenticationEvents`.
Widget? buildGoogleWebButton() => gsi_web.renderButton(
  configuration: gsi_web.GSIButtonConfiguration(
    type: gsi_web.GSIButtonType.standard,
    shape: gsi_web.GSIButtonShape.rectangular,
    text: gsi_web.GSIButtonText.continueWith,
    size: gsi_web.GSIButtonSize.large,
    minimumWidth: 280,
  ),
);
