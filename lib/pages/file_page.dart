import 'dart:io';

import 'package:auto_report/main.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class FilesPage extends StatefulWidget {
  const FilesPage({
    super.key,
  });

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  List<FileSystemEntity> files = [];

  @override
  void initState() {
    super.initState();
    listFiles();
  }

  void listFiles() async {
    final dir = Directory(logsDirPath!);
    final logs =
        await dir.list().where((name) => name.path.endsWith('.log')).toList();
    setState(() => files = logs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: ListView(
              children: ListTile.divideTiles(
                context: context,
                tiles: files.map((file) => _FileCell(
                      file: file,
                    )),
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileCell extends StatelessWidget {
  final FileSystemEntity file;

  const _FileCell({required this.file});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blue.shade100,
      child: Column(children: [
        ListTile(
          title: Text(file.path.substring(file.path.lastIndexOf('/') + 1)),
          // leading: const Icon(Icons.file),
        ),
        ListBody(
          children: [
            Text('size: ${file.statSync().size}'),
            IconButton(
                onPressed: () async {
                  Share.shareXFiles([XFile(file.path)], text: 'Log file.');
                },
                icon: const Icon(Icons.share)),
          ],
        )
      ]),
    );
  }
}
