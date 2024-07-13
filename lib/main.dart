import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:palette_generator/palette_generator.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Color Percentage Detector',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: ColorPercentageScreen(),
    );
  }
}

class ColorPercentageScreen extends StatefulWidget {
  @override
  _ColorPercentageScreenState createState() => _ColorPercentageScreenState();
}

class _ColorPercentageScreenState extends State<ColorPercentageScreen> {
  File? _image;
  ui.Image? _decodedImage;
  List<Color> _colors = [];
  Map<String, double> _colorPercentages = {'Red': 0.0, 'Green': 0.0, 'Blue': 0.0};
  List<int> _pixelColors = [];
  List<int> _highlightedPixels = [];
  final picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _image = File(pickedFile.path);
      await _getColorPercentages();
    }
  }

  Future<void> _getColorPercentages() async {
    if (_image == null) return;

    final image = Image.file(_image!);
    final paletteGenerator = await PaletteGenerator.fromImageProvider(image.image);

    // Obtenir les couleurs du générateur de palette
    setState(() {
      _colors = paletteGenerator.colors.toList();
    });

    // Obtenir les données d'image pour l'analyse des couleurs
    final ByteData data = await _image!.readAsBytes().then((value) => value.buffer.asByteData());
    final ui.Image img = await _loadImage(Uint8List.view(data.buffer));

    setState(() {
      _decodedImage = img;
    });

    _analyzeImageColors(img);
  }

  Future<ui.Image> _loadImage(Uint8List img) async {
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(img, (ui.Image image) {
      return completer.complete(image);
    });
    return completer.future;
  }

  void _analyzeImageColors(ui.Image img) async {
    final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return;

    final Uint8List pixels = byteData.buffer.asUint8List();
    final int length = pixels.lengthInBytes;
    final Map<String, int> colorCounts = {'Red': 0, 'Green': 0, 'Blue': 0};
    int totalPixels = img.width * img.height;

    _pixelColors = pixels.toList(); // Stocker les couleurs des pixels

    for (int i = 0; i < length; i += 4) {
      final int red = pixels[i];
      final int green = pixels[i + 1];
      final int blue = pixels[i + 2];

      colorCounts['Red'] = colorCounts['Red']! + red;
      colorCounts['Green'] = colorCounts['Green']! + green;
      colorCounts['Blue'] = colorCounts['Blue']! + blue;
    }

    setState(() {
      _colorPercentages['Red'] = (colorCounts['Red']! / (totalPixels * 255)) * 100;
      _colorPercentages['Green'] = (colorCounts['Green']! / (totalPixels * 255)) * 100;
      _colorPercentages['Blue'] = (colorCounts['Blue']! / (totalPixels * 255)) * 100;
    });

    // Debug: Afficher les valeurs brutes et les pourcentages
    print('Total Pixels: $totalPixels');
    print('Red Count: ${colorCounts['Red']}');
    print('Green Count: ${colorCounts['Green']}');
    print('Blue Count: ${colorCounts['Blue']}');
    print('Red Percentage: ${_colorPercentages['Red']}%');
    print('Green Percentage: ${_colorPercentages['Green']}%');
    print('Blue Percentage: ${_colorPercentages['Blue']}%');
  }

  void _highlightColor(Color color) {
    final int targetRed = color.red;
    final int targetGreen = color.green;
    final int targetBlue = color.blue;

    _highlightedPixels = [];

    for (int i = 0; i < _pixelColors.length; i += 4) {
      final int red = _pixelColors[i];
      final int green = _pixelColors[i + 1];
      final int blue = _pixelColors[i + 2];

      if (red == targetRed && green == targetGreen && blue == targetBlue) {
        _highlightedPixels.add(i ~/ 4);
      }
    }

    setState(() {});
  }

  void _reset() {
    setState(() {
      _image = null;
      _decodedImage = null;
      _colors = [];
      _colorPercentages = {'Red': 0.0, 'Green': 0.0, 'Blue': 0.0};
      _highlightedPixels = [];
      _pixelColors = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Color Percentage Detector'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _reset,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (_image != null)
                Stack(
                  children: [
                    Image.file(_image!, width: 200, height: 200, fit: BoxFit.cover),
                    if (_highlightedPixels.isNotEmpty && _decodedImage != null)
                      CustomPaint(
                        size: Size(200, 200),
                        painter: HighlightPainter(_highlightedPixels, _decodedImage!.width, _decodedImage!.height),
                      ),
                  ],
                ),
              if (_image == null)
                Text(
                  'No image selected.',
                  style: TextStyle(fontSize: 20),
                ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _pickImage,
                child: Text('Pick Image'),
              ),
              if (_colors.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GridView.count(
                    crossAxisCount: 8,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    children: _colors.map((color) {
                      return GestureDetector(
                        onTap: () => _highlightColor(color),
                        child: Container(
                          width: 20,
                          height: 20,
                          color: color,
                          margin: EdgeInsets.all(2),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              if (_colorPercentages.isNotEmpty && _image != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Text('Red: ${_colorPercentages['Red']!.toStringAsFixed(2)}%'),
                      Text('Green: ${_colorPercentages['Green']!.toStringAsFixed(2)}%'),
                      Text('Blue: ${_colorPercentages['Blue']!.toStringAsFixed(2)}%'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class HighlightPainter extends CustomPainter {
  final List<int> highlightedPixels;
  final int imageWidth;
  final int imageHeight;

  HighlightPainter(this.highlightedPixels, this.imageWidth, this.imageHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final double scaleX = size.width / imageWidth;
    final double scaleY = size.height / imageHeight;

    for (int pixelIndex in highlightedPixels) {
      final int x = pixelIndex % imageWidth;
      final int y = pixelIndex ~/ imageWidth;

      canvas.drawRect(
        Rect.fromLTWH(x * scaleX, y * scaleY, scaleX, scaleY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
