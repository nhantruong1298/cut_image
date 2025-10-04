// ignore_for_file: use_build_context_synchronously

import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html; // Chỉ dành cho web

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scrollBehavior: WebScrollBehavior(),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<PlatformFile> imageFiles = [];

  List<Uint8List> croppedImageBytes = [];
  TextEditingController cropController = TextEditingController(text: '');

  double cropPercentage = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        cropController.text = '13';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Cut cut cut'),
        surfaceTintColor: Colors.white,
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '% crop from top',
                ),
                controller: cropController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              SizedBox(height: screenWidth * 0.05),
              Row(
                children: [
                  ElevatedButton(
                      onPressed: () async {
                        imageFiles.clear();
                        croppedImageBytes.clear();

                        imageFiles = await selectArchive();
                        setState(() {});
                      },
                      child: const Text('select archive ')),
                  const SizedBox(width: 10),
                  ElevatedButton(
                      onPressed: () async {
                        imageFiles.clear();
                        croppedImageBytes.clear();

                        imageFiles = await selectImages();
                        setState(() {});
                      },
                      child: const Text('select images ')),
                ],
              ),
              SizedBox(height: screenWidth * 0.05),
              if (imageFiles.isNotEmpty)
                SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: imageFiles.length,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      return Container(
                        width: 200,
                        height: 200,
                        margin: const EdgeInsets.only(right: 10),
                        child: Image.memory(imageFiles[index].bytes!),
                      );
                    },
                  ),
                ),
              SizedBox(height: screenWidth * 0.05),
              ElevatedButton(
                onPressed: _cropImages,
                child: const Text('crop here!'),
              ),
              SizedBox(height: screenWidth * 0.05),
              if (croppedImageBytes.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: croppedImageBytes.length,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      return Container(
                        width: 200,
                        height: 200,
                        margin: const EdgeInsets.only(right: 10),
                        child: Image.memory(croppedImageBytes[index]),
                      );
                    },
                  ),
                ),
              SizedBox(height: screenWidth * 0.05),
              ElevatedButton(
                onPressed: () async {
                  downloadAllCroppedImages();
                },
                child: const Text('save bitch!'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _cropImages() async {
    cropPercentage = double.tryParse(cropController.text) ?? 0.0;
    croppedImageBytes.clear();

    if (imageFiles.isNotEmpty) {
      await Future.forEach(imageFiles, (file) async {
        final cropped = await cropImageFromTop(cropPercentage, file.bytes!);
        if (cropped != null) {
          croppedImageBytes.add(cropped);
        }
      });

      setState(() {});
    }
  }

  Future<List<PlatformFile>> selectImages() async {
    final List<PlatformFile> imageFiles = [];
    try {
      FilePickerResult? result =
          await FilePicker.platform.pickFiles(allowMultiple: true);

      if (result != null) {
        return result.files;
      }
    } catch (e) {
      return [];
    }

    return imageFiles;
  }

  Future<List<PlatformFile>> selectArchive() async {
    final List<PlatformFile> imageFiles = [];

    try {
      // 1. Chọn Tệp Nén (chỉ cho phép chọn một tệp)
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        // Tùy chọn: Gợi ý cho người dùng chọn tệp zip
        allowedExtensions: ['zip'],
      );

      if (result == null) {
        return []; // Người dùng hủy
      }

      final PlatformFile zippedFile = result.files.single;

      // QUAN TRỌNG: Trên Web, dữ liệu tệp được cung cấp trong thuộc tính 'bytes'
      // chứ không phải 'path'.
      final Uint8List? fileBytes = zippedFile.bytes;

      if (fileBytes == null) {
        // Điều này hiếm khi xảy ra nếu filePicker hoạt động đúng trên Web
        showError('Selected file has no data.');
        return [];
      }

      // 2. Giải Nén Tệp từ Bytes
      // Sử dụng ZipDecoder().decodeBytes() để giải nén trực tiếp từ Uint8List (bytes)
      final archive = ZipDecoder().decodeBytes(fileBytes);

      // 3. Xử lý các Mục đã Giải Nén và Chuyển thành PlatformFile
      for (final file in archive.files) {
        // Chỉ xử lý các tệp (bỏ qua các thư mục)
        if (!file.isFile) continue;

        final String fileName = file.name;

        // Lọc các tệp hình ảnh
        if (fileName.toLowerCase().endsWith('.png') ||
            fileName.toLowerCase().endsWith('.jpg') ||
            fileName.toLowerCase().endsWith('.jpeg')) {
          // Lấy dữ liệu (bytes) của file đã giải nén
          // file.content luôn là Uint8List khi giải nén từ bộ nhớ
          final fileData = file.content;

          // Tạo một PlatformFile mới, chỉ chứa tên và bytes,
          // vì không có path trên Web
          final platformFile = PlatformFile(
            name: fileName,
            size: fileData.length,
            bytes: fileData, // <--- Dữ liệu hình ảnh trong bộ nhớ
            path: null, // Path luôn là null trên Web
          );

          imageFiles.add(platformFile);
        }
      }
    } catch (e) {
      showError('Error selecting or extracting archive: $e');
      return [];
    }

    return imageFiles;
  }

  Future<Uint8List?> cropImageFromTop(
      double percentage, Uint8List imageBytes) async {
    try {
      final image = await decodeImageFromList(imageBytes);

      final cropHeight = (image.height * percentage / 100).round();

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, cropHeight.toDouble(), image.width.toDouble(),
            (image.height - cropHeight).toDouble()),
        Rect.fromLTWH(0, 0, image.width.toDouble(),
            (image.height - cropHeight).toDouble()),
        Paint(),
      );

      // Convert to image and then to bytes
      final picture = recorder.endRecording();
      final croppedImage =
          await picture.toImage(image.width, image.height - cropHeight);
      final byteData =
          await croppedImage.toByteData(format: ImageByteFormat.png);

      return byteData?.buffer.asUint8List();
    } catch (e) {
      showError('Error cropping image: $e');
      return null;
    }
  }

  void downloadAllCroppedImages() {
    if (kIsWeb) {
      if (croppedImageBytes.isEmpty) {
        return;
      }

      final encoder = ZipEncoder();
      final archive = Archive();

      for (int i = 0; i < croppedImageBytes.length; i++) {
        final fileName = 'cropped_image_$i.png';
        final fileData = croppedImageBytes[i]; // Đây là Uint8List

        archive.addFile(
          ArchiveFile(
            fileName,
            fileData.length,
            fileData,
          ),
        );
      }

      final zipData = encoder.encode(archive);

      final zipBytes = Uint8List.fromList(zipData);
      final blob = html.Blob([zipBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);

      html.AnchorElement(href: url)
        ..setAttribute('download', 'cropped_images.zip') // Tên tệp nén
        ..click();

      html.Url.revokeObjectUrl(url);

      Future.delayed(const Duration(seconds: 1), () {});
    }
  }

  void showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class WebScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
      };

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}
