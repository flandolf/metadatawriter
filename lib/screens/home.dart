import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:metadatawriter/services/spotifyservice.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/clientprovider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String filePath = "";
  Metadata currentMetadata = const Metadata();
  String spotifyApiKey = "";
  dynamic spotifyMetadata;
  List<dynamic> avaliableTracks = [];
  final TextEditingController clientIdController = TextEditingController();
  final TextEditingController clientSecretController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _load();
    clientIdController.text = context.read<ClientCredentialsProvider>().clientId;
    clientSecretController.text = context.read<ClientCredentialsProvider>().clientSecret;
    if (context.read<ClientCredentialsProvider>().clientId.isNotEmpty &&
        context.read<ClientCredentialsProvider>().clientSecret.isNotEmpty) {
      getApiKey(
              context.read<ClientCredentialsProvider>().clientId,
              context.read<ClientCredentialsProvider>().clientSecret)
          .then((value) {
        setState(() {
          spotifyApiKey = value;
        });
      });
    }
  }
  void _save() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    prefs.setString('client_id', context.read<ClientCredentialsProvider>().clientId);
    prefs.setString('client_secret', context.read<ClientCredentialsProvider>().clientSecret);
    print(prefs.getString('client_id'));
    print(prefs.getString('client_secret'));
  }

  void _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    context.read<ClientCredentialsProvider>().setClientId(prefs.getString('client_id') ?? "");
    context.read<ClientCredentialsProvider>().setClientSecret(prefs.getString('client_secret') ?? "");
  }

  Future<void> _openFileExplorer() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        filePath = result.files.single.path!;
      });
      await _readMetadata();
    }
  }

  Future<void> _readMetadata() async {
    Metadata metadata = await MetadataGod.readMetadata(file: filePath);
    setState(() {
      currentMetadata = metadata;
    });
  }

  String formatDuration(Duration d) {
    // hh:mm:ss
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  String bytesToMb(int bytes) {
    return "${(bytes / 1024 / 10).toStringAsFixed(2)} MB";
  }

  Future<void> _getSpotifyMetadata() async {
    if (context.read<ClientCredentialsProvider>().clientId.isEmpty ||
        context.read<ClientCredentialsProvider>().clientSecret.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please set Spotify API credentials!")));
      return;
    } else if (filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a file first!")));
      return;
    } else if (spotifyApiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Spotify API key not found, obtaining...")));
      await getApiKey(context.read<ClientCredentialsProvider>().clientId, context.read<ClientCredentialsProvider>().clientSecret)
          .then((value) {
        setState(() {
          spotifyApiKey = value;
        });
      });
    }
    String title = currentMetadata.title ?? "";
    String artist = currentMetadata.artist ?? "";
    String query = "$title $artist";
    await searchMultipleTracks(query, spotifyApiKey, 5).then((value) {
      setState(() {
        avaliableTracks = value;
      });
    });
  }

  Future<void> _writeSpotifyMetadataToFile() async {
    if (spotifyMetadata != null) {
      var picture = http.get(Uri.parse(spotifyMetadata["image"]));
      await MetadataGod.writeMetadata(
          file: filePath,
          metadata: Metadata(
              title: spotifyMetadata["name"],
              artist: spotifyMetadata["artist"],
              album: spotifyMetadata["album"],
              durationMs: double.parse(spotifyMetadata["duration"].toString()),
              albumArtist: spotifyMetadata["albumArtist"],
              trackNumber: spotifyMetadata["trackNumber"],
              year: spotifyMetadata["year"],
              picture: Picture(
                mimeType: 'image/jpeg',
                data: await picture.then((value) => value.bodyBytes),
              )));
      await _readMetadata();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Metadata written successfully")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Metadata Writer"),
          actions: [IconButton(onPressed: () {
            showDialog(context: context, builder: (context){
              return AlertDialog(
                title: const Text("Set Spotify API Credentials"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: clientIdController,
                      decoration: const InputDecoration(labelText: "Client ID"),
                      onChanged: (value) {
                        context.read<ClientCredentialsProvider>().setClientId(value);
                        _save();
                        setState(() {

                        });
                      },
                    ),
                    TextField(
                      controller: clientSecretController,
                      decoration: const InputDecoration(labelText: "Client Secret"),
                      onChanged: (value) {
                        context.read<ClientCredentialsProvider>().setClientSecret(value);
                        _save();
                        setState(() {

                        });
                      },
                    ),
                  ],
                ),
                actions: <Widget>[
                  TextButton(onPressed: () {
                    Navigator.of(context).pop();
                  }, child: const Text("Close"))
                ],
              );
            });
          }, icon: Icon(Icons.settings))],
        ),
        body: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                Text(
                  "Client ID: ${context.read<ClientCredentialsProvider>().clientId}",
                ),
                Text(
                  "Client Secret: ${context.read<ClientCredentialsProvider>().clientSecret}",
                ),
                Card(
                  child: ListTile(
                    title: Text(currentMetadata.title ?? "No Title"),
                    subtitle: Text("${currentMetadata.artist ?? "No Artist"} - "
                        "${currentMetadata.album ?? "No Album"}"),
                    leading: const Icon(Icons.audiotrack),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        Text(formatDuration(
                            currentMetadata.duration ?? Duration.zero)),
                        FilledButton(
                            onPressed: _getSpotifyMetadata,
                            child: const Text("Search")),
                      ],
                    ),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: avaliableTracks.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Card(
                      child: ListTile(
                        onTap: () {
                          setState(() {
                            spotifyMetadata = avaliableTracks[index];
                          });
                          _writeSpotifyMetadataToFile();
                        },
                        title: Text(
                            "${avaliableTracks[index]["name"]} - ${avaliableTracks[index]["artist"]}"),
                        subtitle: Text(
                            "${avaliableTracks[index]["album"]} (${avaliableTracks[index]["year"]})"),
                        leading: Image.network(avaliableTracks[index]["image"]),
                      ),
                    );
                  },
                ),
              ],
            )),
        floatingActionButton: FloatingActionButton(
          onPressed: _openFileExplorer,
          child: const Icon(Icons.add),
        ));
  }
}
