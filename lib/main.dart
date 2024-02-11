import 'package:flutter/material.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:metadatawriter/providers/clientprovider.dart';
import 'package:metadatawriter/screens/home.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MetadataGod.initialize();
  runApp(ChangeNotifierProvider(create: (context) => ClientCredentialsProvider(), child: MainApp()));
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Metadata Writer",
      home: const HomeScreen(),
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepOrange, brightness: Brightness.dark)),
    );
  }
}
