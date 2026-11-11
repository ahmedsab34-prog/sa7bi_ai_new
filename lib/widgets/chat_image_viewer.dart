
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// يعرض صورة رسائل AI أو الصور المنشأة/المعدلة بالحجم الكامل.
Future<void> showChatImageViewer(
  BuildContext context,
  Uint8List imageBytes,
) async {
  if (imageBytes.isEmpty) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black,
    useSafeArea: false,
    builder: (_) => _ChatImageViewerDialog(
      imageBytes: imageBytes,
    ),
  );
}

class _ChatImageViewerDialog extends StatefulWidget {
  const _ChatImageViewerDialog({
    required this.imageBytes,
  });

  final Uint8List imageBytes;

  @override
  State<_ChatImageViewerDialog> createState() =>
      _ChatImageViewerDialogState();
}

class _ChatImageViewerDialogState
    extends State<_ChatImageViewerDialog> {
  final TransformationController _transformationController =
      TransformationController();

  bool _zoomedByDoubleTap = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _toggleDoubleTapZoom() {
    setState(() {
      if (_zoomedByDoubleTap) {
        _transformationController.value = Matrix4.identity();
      } else {
        _transformationController.value = Matrix4.identity()
          ..scale(2.0);
      }

      _zoomedByDoubleTap = !_zoomedByDoubleTap;
    });
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();

    if (mounted) {
      setState(() {
        _zoomedByDoubleTap = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const ValueKey<String>('chat-image-viewer'),
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.black,
      surfaceTintColor: Colors.transparent,
      child: SizedBox.expand(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: _toggleDoubleTapZoom,
                  child: InteractiveViewer(
                    transformationController:
                        _transformationController,
                    minScale: 1,
                    maxScale: 5,
                    panEnabled: true,
                    scaleEnabled: true,
                    boundaryMargin:
                        const EdgeInsets.all(60),
                    clipBehavior: Clip.none,
                    child: SizedBox.expand(
                      child: Center(
                        child: Image.memory(
                          widget.imageBytes,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          errorBuilder: (
                            context,
                            error,
                            stackTrace,
                          ) {
                            return const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white70,
                              size: 52,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.58),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'إغلاق الصورة',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 8,
                left: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.58),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'إعادة ضبط التكبير',
                    onPressed: _resetZoom,
                    icon: const Icon(
                      Icons.center_focus_strong_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: IgnorePointer(
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.62),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 7,
                        ),
                        child: Text(
                          'قرّب بإصبعين • اضغط مرتين للتكبير • اسحب للتحريك',
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
