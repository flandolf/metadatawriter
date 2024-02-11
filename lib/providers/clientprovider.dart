import 'package:flutter/material.dart';

class ClientCredentialsProvider with ChangeNotifier {
  String _clientId = "";
  String _clientSecret = "";

  String get clientId => _clientId;
  String get clientSecret => _clientSecret;

  void setClientId(String id) {
    _clientId = id;
    notifyListeners();
  }

  void setClientSecret(String secret) {
    _clientSecret = secret;
    notifyListeners();
  }
}
