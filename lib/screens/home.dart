import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_taggy/flutter_taggy.dart';
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
  String spotifyApiKey = "";
  dynamic spotifyMetadata;
  TaggyFile? taggyFile;
  Tag? tag;
  List<dynamic> avaliableTracks = [];
  final TextEditingController clientIdController = TextEditingController();
  final TextEditingController clientSecretController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController artistController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _load();
    clientIdController.text =
        context.read<ClientCredentialsProvider>().clientId;
    clientSecretController.text =
        context.read<ClientCredentialsProvider>().clientSecret;
    if (context.read<ClientCredentialsProvider>().clientId.isNotEmpty &&
        context.read<ClientCredentialsProvider>().clientSecret.isNotEmpty) {
      getApiKey(context.read<ClientCredentialsProvider>().clientId,
              context.read<ClientCredentialsProvider>().clientSecret)
          .then((value) {
        setState(() {
          spotifyApiKey = value;
        });
      });
    }
    setState(() {});
  }

  void _save() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    prefs.setString(
        'client_id', context.read<ClientCredentialsProvider>().clientId);
    prefs.setString('client_secret',
        context.read<ClientCredentialsProvider>().clientSecret);
  }

  void _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    context
        .read<ClientCredentialsProvider>()
        .setClientId(prefs.getString('client_id') ?? "");
    context
        .read<ClientCredentialsProvider>()
        .setClientSecret(prefs.getString('client_secret') ?? "");
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
    try {
      taggyFile = await Taggy.readPrimary(filePath);
      setState(() {
        tag = taggyFile?.firstTagIfAny;
      });
    } catch (error) {
      _showSnackBar("Error: $error");
    }
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

  Future<void> _getSpotifyMetadata({
    String title = "",
    String artist = "",
  }) async {
    if (context.read<ClientCredentialsProvider>().clientId.isEmpty ||
        context.read<ClientCredentialsProvider>().clientSecret.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please set Spotify API credentials!")));
      return;
    } else if (filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a file first!")));
      return;
    } else if (tag?.trackTitle == "No Title" ||
        tag?.trackArtist == "No Artist") {
      final TextEditingController titleController = TextEditingController();
      final TextEditingController artistController = TextEditingController();
      await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text("Error"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: "Title"),
                  ),
                  TextField(
                    controller: artistController,
                    decoration: const InputDecoration(labelText: "Artist"),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                    onPressed: () {
                      title = titleController.text;
                      artist = artistController.text;
                      Navigator.of(context).pop();
                    },
                    child: const Text("Submit"))
              ],
            );
          });
    } else if (spotifyApiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Spotify API key not found, obtaining...")));
      await getApiKey(context.read<ClientCredentialsProvider>().clientId,
              context.read<ClientCredentialsProvider>().clientSecret)
          .then((value) {
        setState(() {
          spotifyApiKey = value;
        });
      });
    }
    if (title.isEmpty) {
      title = tag?.trackTitle ?? "";
    }
    if (artist.isEmpty) {
      artist = tag?.trackArtist ?? "";
    }
    String query = "$title $artist";
    await searchMultipleTracks(query, spotifyApiKey, 5).then((value) {
      setState(() {
        avaliableTracks = value;
      });
    });
  }

  Future<void> _writeSpotifyMetadataToFile() async {
    if (spotifyMetadata != null) {
      try {
        var pictureResponse =
            await http.get(Uri.parse(spotifyMetadata["image"]));
        if (pictureResponse.statusCode != 200) {
          throw Exception(
              "Failed to fetch image. Status code: ${pictureResponse.statusCode}");
        }

        Uint8List imageBytes = pictureResponse.bodyBytes;
        Tag newTag = Tag(
          tagType: tag!.tagType,
          trackTitle: spotifyMetadata["name"],
          trackArtist: spotifyMetadata["artist"],
          album: spotifyMetadata["album"],
          year: spotifyMetadata["year"],
          pictures: [Picture(picType: PictureType.Icon, picData: imageBytes)],
        );

        await Taggy.writePrimary(
            path: filePath, tag: newTag, keepOthers: false);

        if (!_metadataEquals(newTag, spotifyMetadata)) {
          _showSnackBar("Error writing metadata!");
        } else {
          _showSnackBar("Metadata written successfully");
        }
        setState(() {
          tag = newTag;
        });
      } catch (error) {
        _showSnackBar("Error: $error");
      }
    }
  }

  bool _metadataEquals(Tag metadata, Map<String, dynamic> spotifyMetadata) {
    return metadata.trackTitle == spotifyMetadata["name"] &&
        metadata.trackArtist == spotifyMetadata["artist"] &&
        metadata.album == spotifyMetadata["album"] &&
        metadata.year == spotifyMetadata["year"];
  }

  void _showSnackBar(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Metadata Writer"),
          actions: [
            IconButton(
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text("Set Spotify API Credentials"),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              TextField(
                                controller: clientIdController,
                                decoration: const InputDecoration(
                                    labelText: "Client ID"),
                                onChanged: (value) {
                                  context
                                      .read<ClientCredentialsProvider>()
                                      .setClientId(value);
                                  _save();
                                  setState(() {});
                                },
                              ),
                              TextField(
                                controller: clientSecretController,
                                decoration: const InputDecoration(
                                    labelText: "Client Secret"),
                                onChanged: (value) {
                                  context
                                      .read<ClientCredentialsProvider>()
                                      .setClientSecret(value);
                                  _save();
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                          actions: <Widget>[
                            TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text("Close"))
                          ],
                        );
                      });
                },
                icon: const Icon(Icons.settings))
          ],
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                        onPressed: () {
                          getApiKey(
                                  context
                                      .read<ClientCredentialsProvider>()
                                      .clientId,
                                  context
                                      .read<ClientCredentialsProvider>()
                                      .clientSecret)
                              .then((value) {
                            setState(() {
                              spotifyApiKey = value;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("API Key refreshed!")));
                          });
                        },
                        icon: const Icon(Icons.refresh))
                  ],
                ),
                Card(
                  child: ListTile(
                    leading: tag?.pictures[0] != null
                        ? Image.memory(tag!.pictures[0].picData)
                        : const Icon(Icons.music_note),
                    title: Text(tag?.trackTitle ?? "No Title"),
                    subtitle: Text("${tag?.trackArtist ?? "No Artist"} - "
                        "${tag?.album ?? "No Album"}"),
                    trailing: FilledButton(
                        onPressed: _getSpotifyMetadata,
                        child: const Text("Search")),
                  ),
                ),
                Card(
                  child: ListTile(
                      title: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text("File Path"),
                      if (filePath.isNotEmpty) Text(filePath),
                    ],
                  )),
                ),
                Card(
                  child: ListTile(
                      title: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        decoration: const InputDecoration(hintText: "Title"),
                        controller: titleController,
                      ),
                      TextField(
                        decoration: const InputDecoration(hintText: "Artist"),
                        controller: artistController,
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                      FilledButton(
                          onPressed: () {
                            _getSpotifyMetadata(
                                artist: artistController.text,
                                title: titleController.text);
                          },
                          child: const Text("Search"))
                    ],
                  )),
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
