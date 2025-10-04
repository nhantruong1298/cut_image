import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FullScreenImageViewer extends StatefulWidget {
  final List<Uint8List> imagesBytes;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.imagesBytes,
    required this.initialIndex,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Phương thức xử lý sự kiện nhấn phím
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        // Phím mũi tên phải (→)
        _nextImage();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        // Phím mũi tên trái (←)
        _previousImage();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _nextImage() {
    if (_currentIndex < widget.imagesBytes.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _previousImage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      // Bắt sự kiện phím toàn cục trên widget này
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Stack(
        children: [
          // Hiển thị PageView để trượt giữa các ảnh
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imagesBytes.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: InteractiveViewer(
                    // Cho phép zoom và pan ảnh
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.memory(
                      widget.imagesBytes[index],
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                            child: Text('Lỗi tải ảnh lớn',
                                style: TextStyle(color: Colors.white)));
                      },
                    ),
                  ),
                ),
              );
            },
          ),

          // Nút Đóng (X)
          Positioned(
            top: 40,
            right: 40,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // Nút điều hướng Trái
          if (_currentIndex > 0)
            Positioned.fill(
              left: 10,
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios,
                      color: Colors.white, size: 40),
                  onPressed: _previousImage,
                ),
              ),
            ),

          // Nút điều hướng Phải
          if (_currentIndex < widget.imagesBytes.length - 1)
            Positioned.fill(
              right: 10,
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.arrow_forward_ios,
                      color: Colors.white, size: 40),
                  onPressed: _nextImage,
                ),
              ),
            ),

          // Chỉ số hiện tại
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '${_currentIndex + 1} / ${widget.imagesBytes.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
