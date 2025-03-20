import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class CodeDisplayScreen extends StatelessWidget {
  final List<dynamic> codeData;

  const CodeDisplayScreen({Key? key, required this.codeData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Code Samples'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 350,
            childAspectRatio: 3 / 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: codeData.length,
          itemBuilder: (context, index) {
            final item = codeData[index];
            final label = item['Label'] ?? 'Unnamed Code';
            final code = item['Code'] ?? '';

            return CodeTile(
              label: label,
              code: code,
            );
          },
        ),
      ),
    );
  }
}

class CodeTile extends StatelessWidget {
  final String label;
  final String code;

  const CodeTile({
    Key? key,
    required this.label,
    required this.code,
  }) : super(key: key);

  Future<void> _copyToClipboard(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _downloadCode(BuildContext context) async {
    try {
      // Request storage permission
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Storage permission denied');
        }
      }

      // Make filename safe
      String safeFileName = label.replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .toLowerCase();
      
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null) {
        throw Exception('Cannot find downloads directory');
      }

      final String filePath = '${downloadsDir.path}/${safeFileName}.ino';
      final File file = File(filePath);
      await file.writeAsString(code);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File saved to ${file.path}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _downloadCode(context),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        code,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                        maxLines: 10,
                        overflow: TextOverflow.fade,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tap to download', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                      Icon(Icons.download, color: Theme.of(context).colorScheme.primary),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () => _copyToClipboard(context),
                tooltip: 'Copy to clipboard',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
