import 'dart:ui';

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

  double cropPercentage = 0.0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cut cut cut'),
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
                onChanged: (value) {
                  setState(() {
                    cropPercentage = double.tryParse(value) ?? 0.0;
                  });
                },
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              SizedBox(height: screenWidth * 0.05),
              ElevatedButton(
                  onPressed: () async {
                    imageFiles.clear();
                    croppedImageBytes.clear();

                    imageFiles = await selectImageFolder();
                    setState(() {});
                  },
                  child: const Text('select images bitch!')),
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
                onPressed: () async {
                  croppedImageBytes.clear();

                  if (imageFiles.isNotEmpty) {
                    await Future.forEach(imageFiles, (file) async {
                      final cropped =
                          await cropImageFromTop(cropPercentage, file.bytes!);
                      if (cropped != null) {
                        croppedImageBytes.add(cropped);
                      }
                    });

                    setState(() {});
                  }
                },
                child: const Text('crop here!'),
              ),
              SizedBox(height: screenWidth * 0.05),
              if (croppedImageBytes.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: croppedImageBytes.length,
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

  Future<List<PlatformFile>> selectImageFolder() async {
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

  Future<Uint8List?> cropImageFromTop(
      double percentage, Uint8List imageBytes) async {
    try {
      // Decode the image
      final image = await decodeImageFromList(imageBytes);

      // Calculate crop height
      final cropHeight = (image.height * percentage / 100).round();

      // Create a new canvas with cropped dimensions
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw the cropped portion
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
      print('Error cropping image: $e');
      return null;
    }
  }

  void downloadAllCroppedImages() {
    if (kIsWeb) {
      for (int i = 0; i < croppedImageBytes.length; i++) {
        final blob = html.Blob([croppedImageBytes[i]]);
        final url = html.Url.createObjectUrlFromBlob(blob);

        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'cropped_image_$i.png')
          ..click();

        html.Url.revokeObjectUrl(url);
      }

      Future.delayed(const Duration(seconds: 1), () {
        imageFiles.clear();
        croppedImageBytes.clear();
        setState(() {});
      });
    }
  }
}

class WebScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse, // Thêm hỗ trợ cuộn bằng chuột
        // Bạn có thể thêm các thiết bị khác nếu cần
      };

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}
