import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:metadatawriter/services/spotifyservice.dart';
import 'package:http/http.dart' as http;

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
  @override
  void initState() {
    super.initState();
    getApiKey().then((value) {
      setState(() {
        spotifyApiKey = value;
      });
    });
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
    if (spotifyApiKey.isEmpty) {
      getApiKey().then((value) {
        setState(() {
          spotifyApiKey = value;
        });
      });
    } else if (filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a file first")));
      return;
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
          actions: [IconButton(onPressed: () {}, icon: Icon(Icons.settings))],
        ),
        body: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
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
