import 'dart:isolate';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import '../models/media_file.dart';

@pragma('vm:entry-point')
class DownloadService extends ChangeNotifier {
  static const String _portName = 'downloader_send_port';
  final ReceivePort _port = ReceivePort();
  
  Map<String, DownloadTaskStatus> _taskStatuses = {};
  Map<String, int> _taskProgress = {};

  DownloadService() {
    _initPort();
  }

  void _initPort() {
    IsolateNameServer.registerPortWithName(_port.sendPort, _portName);
    _port.listen((dynamic data) {
      String id = data[0];
      DownloadTaskStatus status = data[1];
      int progress = data[2];
      
      _taskStatuses[id] = status;
      _taskProgress[id] = progress;
      notifyListeners();
    });

    FlutterDownloader.registerCallback(downloadCallback);
  }

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort? send = IsolateNameServer.lookupPortByName(_portName);
    send?.send([id, DownloadTaskStatus.fromInt(status), progress]);
  }

  Future<void> downloadBatch(List<MediaFile> files) async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      await [Permission.videos, Permission.audio].request();
    }

    final directory = await getExternalStorageDirectory();
    final downloadPath = '/storage/emulated/0/Download'; // Public Downloads folder
    debugPrint('DownloadBatch: path=$downloadPath, files=${files.length}');

    for (var file in files) {
      if (file.isSelected) {
        final taskId = DateTime.now().millisecondsSinceEpoch.toString();
        file.taskId = taskId; // Associate taskId with file
        debugPrint('Starting download: ${file.name} -> $downloadPath/${file.name}');
        await _downloadWithHttp(file.url, '$downloadPath/${file.name}', file.name, taskId);
      }
    }
  }

  void _sendProgressUpdate(String taskId, DownloadTaskStatus status, int progress) {
    _taskStatuses[taskId] = status;
    _taskProgress[taskId] = progress;
    notifyListeners();
    
    // Check if all downloads are complete
    if (status == DownloadTaskStatus.complete || status == DownloadTaskStatus.failed) {
      _checkAllDownloadsComplete();
    }
  }

  void _checkAllDownloadsComplete() {
    final allTasks = _taskStatuses.entries.where((entry) => 
        entry.value == DownloadTaskStatus.complete || 
        entry.value == DownloadTaskStatus.failed
    ).length;
    
    final totalTasks = _taskStatuses.length;
    
    if (allTasks == totalTasks && totalTasks > 0) {
      final completedTasks = _taskStatuses.entries.where((entry) => 
          entry.value == DownloadTaskStatus.complete
      ).length;
      
      if (completedTasks > 0) {
        _showDownloadCompleteNotification();
      }
    }
  }

  void _showDownloadCompleteNotification() {
    // This will be called from UI to show the toast
    notifyListeners();
  }

  Future<void> _downloadWithHttp(String url, String savePath, String fileName, String taskId) async {
    const maxRetries = 5;
    const timeout = Duration(seconds: 120);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // Notify start
        _sendProgressUpdate(taskId, DownloadTaskStatus.running, 0);

        final uri = Uri.parse(url);
        final request = http.Request('GET', uri);
        debugPrint('Sending request to $url');
        final streamedResponse = await request.send().timeout(timeout);
        debugPrint('Got response');

        if (streamedResponse.statusCode != 200) {
          throw Exception('HTTP ${streamedResponse.statusCode}');
        }

        final contentLength = streamedResponse.contentLength ?? 0;
        debugPrint('Response: statusCode=${streamedResponse.statusCode}, contentLength=$contentLength');
        final file = File(savePath);
        final sink = file.openWrite();

        int downloaded = 0;
        debugPrint('Streaming start: $url');
        await for (final chunk in streamedResponse.stream) {
          sink.add(chunk);
          downloaded += chunk.length;
          final progress = contentLength > 0 ? ((downloaded / contentLength) * 100).round() : 0;
          _sendProgressUpdate(taskId, DownloadTaskStatus.running, progress);
          debugPrint('Progress: $progress% (downloaded=$downloaded, total=$contentLength)');
        }
        debugPrint('Streaming finished');

        await sink.close();
        _sendProgressUpdate(taskId, DownloadTaskStatus.complete, 100);
        return;
      } catch (e) {
        _sendProgressUpdate(taskId, DownloadTaskStatus.failed, -1);
        if (attempt == maxRetries) rethrow;
        await Future.delayed(Duration(seconds: 2 * attempt));
      }
    }
  }

  DownloadTaskStatus getStatus(String taskId) => _taskStatuses[taskId] ?? DownloadTaskStatus.undefined;
  int getProgress(String taskId) => _taskProgress[taskId] ?? 0;
  
  // Getters for UI to access download status
  Map<String, DownloadTaskStatus> get allStatuses => Map.from(_taskStatuses);
  Map<String, int> get allProgress => Map.from(_taskProgress);
  
  void resetCompletionFlag() {
    // This will be called from UI to reset the completion flag
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping(_portName);
    super.dispose();
  }
}
