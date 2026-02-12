import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import '../models/media_file.dart';
import '../services/scraper_service.dart';
import '../services/download_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  List<MediaFile> _files = [];
  bool _isLoading = false;

  // Colores solicitados
  final Color _bgLight = const Color(0xFFECEFF1);
  final Color _primaryDark = const Color(0xFF191970);

  // --- Lógica original mantenida ---
  Future<void> _scanUrl() async {
    if (_urlController.text.isEmpty) return;
    setState(() { _isLoading = true; _files = []; });
    try {
      final results = await ScraperService.scanUrl(_urlController.text);
      setState(() { _files = results; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  void _toggleFile(int index) {
    setState(() { _files[index].isSelected = !_files[index].isSelected; });
  }

  void _downloadSelected() {
    final selectedFiles = _files.where((f) => f.isSelected).toList();
    if (selectedFiles.isEmpty) return;
    context.read<DownloadService>().downloadBatch(selectedFiles);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Añadido a la cola de descarga'),
        backgroundColor: _primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  IconData _getIcon(MediaType type) {
    switch (type) {
      case MediaType.video: return Icons.play_arrow_rounded;
      case MediaType.subtitle: return Icons.closed_caption_rounded;
      case MediaType.audio: return Icons.audiotrack_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: Column(
        children: [
          // Header Minimalista
          Container(
            padding: const EdgeInsets.fromLTRB(25, 60, 25, 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(35)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Descagas Visuales", style: TextStyle(color: _primaryDark, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                const Text("Gestor de descargas local, carpetas completas", style: TextStyle(color: Colors.blueGrey, fontSize: 14)),
                const SizedBox(height: 25),

                // Input estilizado y minimalista
                Container(
                  decoration: BoxDecoration(
                    color: _bgLight.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _urlController,
                    style: TextStyle(color: _primaryDark),
                    decoration: InputDecoration(
                      hintText: "URL de la carpeta...",
                      hintStyle: const TextStyle(color: Colors.black, fontSize: 15),
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.link_rounded, color: Colors.black),
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Botón de búsqueda suave
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _scanUrl,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("Analizar Directorio", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),

          // Lista de resultados
          Expanded(
            child: _files.isEmpty
                ? _buildEmptyState()
                : _buildFilesList(),
          ),
        ],
      ),
      floatingActionButton: _files.any((f) => f.isSelected)
          ? FloatingActionButton.extended(
        onPressed: _downloadSelected,
        backgroundColor: _primaryDark,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        label: const Text("Descargar selección", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.download_rounded, color: Colors.white),
      )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_motion_rounded, size: 60, color: _primaryDark.withOpacity(0.1)),
          const SizedBox(height: 10),
          Text("Listo para escanear", style: TextStyle(color: _primaryDark.withOpacity(0.3), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildFilesList() {
    return ListView.builder(
      itemCount: _files.length,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      itemBuilder: (context, index) {
        final file = _files[index];
        final downloadService = context.watch<DownloadService>();
        final progress = file.taskId != null ? downloadService.getProgress(file.taskId!) : 0;
        final status = file.taskId != null ? downloadService.getStatus(file.taskId!) : DownloadTaskStatus.undefined;

        bool isRunning = status == DownloadTaskStatus.running;
        bool isDone = status == DownloadTaskStatus.complete;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: file.isSelected ? _primaryDark.withOpacity(0.2) : Colors.transparent,
              width: 2,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => _toggleFile(index),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _bgLight,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(_getIcon(file.type), color: _primaryDark),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _primaryDark, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        if (isRunning || isDone) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: isDone ? 1.0 : progress / 100,
                              minHeight: 6,
                              backgroundColor: _bgLight,
                              color: isDone ? Colors.green : _primaryDark,
                            ),
                          ),
                        ] else
                          Text(file.url.split('/').last, style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: file.isSelected,
                    activeColor: _primaryDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    onChanged: (_) => _toggleFile(index),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}