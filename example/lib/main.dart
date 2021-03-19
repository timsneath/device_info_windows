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
  late DeviceInfoWindows deviceInfo;
  late List<String> processes;

  @override
  void initState() {
    super.initState();

    deviceInfo = DeviceInfoWindows();
    processes = deviceInfo.listRunningProcesses();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: Text('Process Viewer (${processes.length} processes)'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(10),
            children: [
              DataTable(
                columns: const [
                  DataColumn(label: Text('Process')),
                ],
                rows: [
                  for (final process in processes)
                    DataRow(
                      cells: [
                        DataCell(Text(process)),
                      ],
                    ),
                ],
              ),
            ],
          ),
          floatingActionButton: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                processes = deviceInfo.listRunningProcesses();
              });
            },
          ),
        ),
      );
}
