import 'package:flutter/material.dart';
import 'package:device_info_windows/device_info_windows.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  DeviceInfoWindows deviceInfo;
  List<String> processes;

  @override
  void initState() {
    super.initState();

    deviceInfo = DeviceInfoWindows();
    deviceInfo.Initialize();
    processes = deviceInfo.Processes;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Process Viewer'),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  processes = deviceInfo.Processes;
                });
              },
            )
          ],
        ),
        body: ListView(
          children: [
            for (var process in processes) Text(process),
          ],
        ),
      ),
    );
  }
}
