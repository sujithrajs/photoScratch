import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(MaterialApp(home: ScratchRevealApp()));

class ScratchRevealApp extends StatefulWidget {
  @override
  State<ScratchRevealApp> createState() => _ScratchRevealAppState();
}

class _ScratchRevealAppState extends State<ScratchRevealApp> {
  List<Uint8List> _imageBytesList = [];
  ui.Image? _currentImage;
  int? _currentImageIndex;

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked != null && picked.isNotEmpty) {
      _imageBytesList = [];
      for (final file in picked) {
        final bytes = await file.readAsBytes();
        _imageBytesList.add(bytes);
      }
      // Show first image by default
      _pickRandomImage();
    }
    setState(() {});
  }

  Future<void> _pickRandomImage() async {
    if (_imageBytesList.isEmpty) return;
    final random = Random();
    int index = random.nextInt(_imageBytesList.length);
    // To avoid picking the same image again in a row
    if (_currentImageIndex != null && _imageBytesList.length > 1) {
      while (index == _currentImageIndex) {
        index = random.nextInt(_imageBytesList.length);
      }
    }
    final codec = await ui.instantiateImageCodec(_imageBytesList[index]);
    final frame = await codec.getNextFrame();
    setState(() {
      _currentImageIndex = index;
      _currentImage = frame.image;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Random Scratch to Reveal')),
      body: Center(
        child: _imageBytesList.isEmpty
            ? ElevatedButton(
          onPressed: _pickImages,
          child: Text('Pick Images'),
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_currentImage != null)
              SizedBox(
                width: 300,
                height: 300,
                child: RevealImageWidget(
                  key: ValueKey(_currentImageIndex), // reset painter
                  image: _currentImage!,
                ),
              )
            else
              CircularProgressIndicator(),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _pickRandomImage,
                  child: Text('Next (Random)'),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _pickImages,
                  child: Text('Pick More Images'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RevealImageWidget extends StatefulWidget {
  final ui.Image image;
  const RevealImageWidget({required this.image, Key? key}) : super(key: key);

  @override
  State<RevealImageWidget> createState() => _RevealImageWidgetState();
}

class _RevealImageWidgetState extends State<RevealImageWidget> {
  final _paths = <Offset>[];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        RenderBox box = context.findRenderObject() as RenderBox;
        Offset local = box.globalToLocal(details.globalPosition);
        setState(() {
          _paths.add(local);
        });
      },
      child: CustomPaint(
        size: Size(300, 300),
        painter: _ScratchPainter(
          image: widget.image,
          points: _paths,
        ),
      ),
    );
  }
}

class _ScratchPainter extends CustomPainter {
  final ui.Image image;
  final List<Offset> points;
  _ScratchPainter({required this.image, required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw image but clip with mask
    Paint paint = Paint();

    // Offscreen mask layer
    final recorder = ui.PictureRecorder();
    final maskCanvas = Canvas(recorder);
    maskCanvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.transparent);

    // Draw all reveal points
    for (final p in points) {
      maskCanvas.drawCircle(p, 20, Paint()..color = Colors.white);
    }
    final maskPicture = recorder.endRecording();
    final maskImage = maskPicture.toImageSync(size.width.toInt(), size.height.toInt());

    // Draw image masked
    canvas.saveLayer(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint());
    // Draw image
    paint.isAntiAlias = true;
    paint.filterQuality = FilterQuality.high;
    canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(0, 0, size.width, size.height),
        paint);
    // Mask with reveal
    paint.blendMode = BlendMode.dstIn;
    canvas.drawImage(maskImage, Offset.zero, paint);
    canvas.restore();

    // Optional: Draw a frame
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.grey
          ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(_ScratchPainter oldDelegate) => true;
}
