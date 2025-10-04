import 'dart:typed_data';

import 'package:flutter/material.dart';

class AppImage extends StatelessWidget {
  final Uint8List data;
  final double width;
  final double height;
  final VoidCallback? onDelete;
  final VoidCallback? onRotate;
  final VoidCallback? onTap;

  const AppImage({
    super.key,
    required this.data,
    this.width = 200,
    this.height = 200,
    this.onDelete,
    this.onRotate,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Image.memory(
            data,
            width: width,
            height: height,
            fit: BoxFit.fill,
          ),
          // Delete button (top right)
          if (onDelete != null)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: onDelete,
                  tooltip: 'Xoá',
                ),
              ),
            ),
          // Rotate button (bottom right)
          if (onRotate != null)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.rotate_right, color: Colors.blue),
                  onPressed: onRotate,
                  tooltip: 'Xoay',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
