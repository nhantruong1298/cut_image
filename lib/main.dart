// ignore_for_file: use_build_context_synchronously

import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:cut_image/widgets/app_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html; // Chỉ dành cho web
import 'package:image/image.dart' as img;

import 'widgets/full_image_viewer.dart';

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
  List<Uint8List> selectedImages = [];

  List<Uint8List> croppedImages = [];
  TextEditingController cropController = TextEditingController(text: '');

  double cropPercentage = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        cropController.text = '10';
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
          backgroundColor: Colors.white),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), labelText: '% crop from top'),
                controller: cropController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              SizedBox(height: screenWidth * 0.05),
              Row(
                children: [
                  _buildSelectArchiveBtn(),
                  const SizedBox(width: 20),
                  _buildSelectImagesBtn()
                ],
              ),
              SizedBox(height: screenWidth * 0.05),
              if (selectedImages.isNotEmpty) _buildListSelectedImages(),
              SizedBox(height: screenWidth * 0.05),
              ElevatedButton(
                onPressed: () => _cropImages(),
                child: const Text('Crop !!!'),
              ),
              SizedBox(height: screenWidth * 0.05),
              if (croppedImages.isNotEmpty) _buildListCroppedImages(),
              SizedBox(height: screenWidth * 0.05),
              ElevatedButton(
                onPressed: downloadAllCroppedImages,
                child: const Text('Download the goods!  📸 ✨'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SizedBox _buildListCroppedImages() {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: croppedImages.length,
        physics: const AlwaysScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AppImage(
              data: croppedImages[index],
              onTap: () => _showFullImage(context, index),
            ),
          );
        },
      ),
    );
  }

  SizedBox _buildListSelectedImages() {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: selectedImages.length,
        physics: const AlwaysScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AppImage(
              data: selectedImages[index],
              onDelete: () => setState(() {
                selectedImages.removeAt(index);
              }),
              onRotate: () {
                rotateImageBytes(selectedImages[index], 90)
                    .then((rotatedBytes) {
                  if (rotatedBytes != null) {
                    selectedImages[index] = rotatedBytes;
                    setState(() {});
                  }
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectImagesBtn() {
    return ElevatedButton(
        onPressed: () async {
          _clearData(selectedImages: true, croppedImages: true);
          selectedImages = await selectImages();
          setState(() {});
        },
        child: const Text('Select images'));
  }

  Widget _buildSelectArchiveBtn() {
    return ElevatedButton(
        onPressed: () async {
          _clearData(selectedImages: true, croppedImages: true);
          selectedImages = await selectArchive();
          setState(() {});
        },
        child: const Text('Select archive (zip)'));
  }

  void _clearData({
    bool selectedImages = false,
    bool croppedImages = false,
  }) {
    if (selectedImages) {
      this.selectedImages.clear();
    }
    if (croppedImages) {
      this.croppedImages.clear();
    }
  }

  Future<Uint8List?> rotateImageBytes(
      Uint8List originalBytes, int angle) async {
    img.Image? originalImage = img.decodeImage(originalBytes);
    if (originalImage == null) return null;
    img.Image rotatedImage = img.copyRotate(originalImage, angle: angle);
    return Uint8List.fromList(img.encodeJpg(rotatedImage)); // Giả sử ảnh là JPG
  }

  void _cropImages() async {
    cropPercentage = double.tryParse(cropController.text) ?? 0.0;
    croppedImages.clear();

    if (selectedImages.isNotEmpty) {
      await Future.forEach(selectedImages, (file) async {
        final cropped = await cropImageFromTop(cropPercentage, file);
        if (cropped != null) {
          croppedImages.add(cropped);
        }
      });

      setState(() {});
    }
  }

  Future<List<Uint8List>> selectImages() async {
    final List<Uint8List> imageFiles = [];
    try {
      FilePickerResult? result =
          await FilePicker.platform.pickFiles(allowMultiple: true);

      if (result != null) {
        return result.files.map((file) => file.bytes!).toList();
      }
    } catch (e) {
      return [];
    }

    return imageFiles;
  }

  Future<List<Uint8List>> selectArchive() async {
    final List<Uint8List> imageFiles = [];

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null) {
        return [];
      }

      final PlatformFile zippedFile = result.files.single;

      final Uint8List? fileBytes = zippedFile.bytes;

      if (fileBytes == null) {
        showError('Selected file has no data.');
        return [];
      }

      final archive = ZipDecoder().decodeBytes(fileBytes);

      for (final file in archive.files) {
        if (!file.isFile) continue;

        final String fileName = file.name;

        if (fileName.toLowerCase().endsWith('.png') ||
            fileName.toLowerCase().endsWith('.jpg') ||
            fileName.toLowerCase().endsWith('.jpeg')) {
          final fileData = file.content;

          final platformFile = PlatformFile(
            name: fileName,
            size: fileData.length,
            bytes: fileData,
            path: null,
          );

          if (platformFile.bytes == null) {
            continue;
          }

          imageFiles.add(platformFile.bytes!);
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
      if (croppedImages.isEmpty) {
        return;
      }

      final encoder = ZipEncoder();
      final archive = Archive();

      for (int i = 0; i < croppedImages.length; i++) {
        final fileName = 'cropped_image_$i.png';
        final fileData = croppedImages[i]; // Đây là Uint8List

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

      Future.delayed(const Duration(seconds: 1), () {
        selectedImages.clear();
        croppedImages.clear();
        setState(() {});
      });
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

  void _showFullImage(BuildContext context, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9), // Màu nền tối
      builder: (BuildContext context) {
        return FullScreenImageViewer(
          imagesBytes: croppedImages,
          initialIndex: initialIndex,
        );
      },
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
