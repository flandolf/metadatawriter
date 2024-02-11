import 'dart:convert';

import 'package:http/http.dart' as http;

Future<String> getApiKey(String client_id, String client_secret) async {
  final response = await http.post(
      Uri.parse(
          "https://accounts.spotify.com/api/token?grant_type=client_credentials"),
      headers: {
        "Authorization":
            "Basic ${const Base64Encoder().convert(utf8.encode("$client_id:$client_secret"))}",
        "Content-Type": "application/x-www-form-urlencoded",
      });
  var json = jsonDecode(response.body);
  return json["access_token"];
}

Future<dynamic> searchMultipleTracks(
    String query, String token, int amount) async {
  final response = await http.get(
      Uri.parse("https://api.spotify.com/v1/search?q=$query&type=track"),
      headers: {"Authorization": "Bearer $token"});
  var json = jsonDecode(response.body);
  if (response == 400) {
    return null;
  }
  List<dynamic> tracks = [];
  for (int i = 0; i < amount; i++) {
    tracks.add({
      "name": json["tracks"]["items"][i]["name"],
      "artist": json["tracks"]["items"][i]["artists"][0]["name"],
      "album": json["tracks"]["items"][i]["album"]["name"],
      "duration": json["tracks"]["items"][i]["duration_ms"],
      "url": json["tracks"]["items"][i]["external_urls"]["spotify"],
      "image": json["tracks"]["items"][i]["album"]["images"][0]["url"],
      "year": int.parse(
          json["tracks"]["items"][i]["album"]["release_date"].split("-")[0]),
      "albumArtist": json["tracks"]["items"][i]["album"]["artists"][0]["name"],
      "trackNumber": json["tracks"]["items"][i]["track_number"],
    });
  }
  return tracks;
}
