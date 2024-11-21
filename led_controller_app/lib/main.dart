import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

void main() {
  runApp(LedControllerApp());
}

class LedControllerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LED Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.cyan,
        brightness: Brightness.dark,
      ),
      home: LedControllerPage(),
    );
  }
}

class LedControllerPage extends StatefulWidget {
  @override
  _LedControllerPageState createState() => _LedControllerPageState();
}

class _LedControllerPageState extends State<LedControllerPage>
    with SingleTickerProviderStateMixin {
  Color _currentColor = Colors.white;
  String _esp32Ip = '192.168.0.239';
  double _brightness = 1.0;
  bool _isOn = true;

  List<Map<String, dynamic>> presets = [
    {'name': 'Blade Runner', 'preset': 'blade_runner'},
    {'name': 'Mruganie', 'preset': 'blink'},
    {'name': 'Niebieski', 'preset': 'blue'},
    {'name': 'Czerwony', 'preset': 'red'},
    {'name': 'Zielony', 'preset': 'green'},
    {'name': 'Biały', 'preset': 'white'},
  ];

  late TabController _tabController;

  // Mapa kolorów dla segmentów (do zakładki Custom LEDs)
  Map<int, Color> segmentColors = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  Future<void> _sendRequest(String endpoint,
      [Map<String, String>? params]) async {
    final url = Uri.http(_esp32Ip, endpoint, params);
    try {
      final response = await http.get(url);
      print('Odpowiedź: ${response.body}');
    } catch (e) {
      print('Błąd: $e');
    }
  }

  Future<void> _setColor(Color color) async {
    setState(() {
      _currentColor = color;
    });
    await _sendRequest('/setColor', {
      'r': '${color.red}',
      'g': '${color.green}',
      'b': '${color.blue}',
    });
  }

  Future<void> _setBrightness(double brightness) async {
    setState(() {
      _brightness = brightness;
    });
    await _sendRequest('/setBrightness', {
      'brightness': '${(brightness * 255).toInt()}',
    });
  }

  Future<void> _turnOnOff(bool isOn) async {
    setState(() {
      _isOn = isOn;
    });
    if (isOn) {
      await _sendRequest('/turnOn');
    } else {
      await _sendRequest('/turnOff');
    }
  }

  Future<void> _setPreset(String preset) async {
    await _sendRequest('/setPreset', {'preset': preset});
  }

  void _openColorPicker({bool isPreset = false}) async {
    Color pickedColor = _currentColor;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Wybierz kolor'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _currentColor,
            onColorChanged: (Color color) {
              pickedColor = color;
            },
            showLabel: false,
            enableAlpha: false, // Wyłączenie przezroczystości
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Anuluj'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );

    if (pickedColor != null) {
      if (isPreset) {
        await _addPreset(pickedColor);
      } else {
        await _setColor(pickedColor);
      }
    }
  }

  Future<void> _addPreset(Color color) async {
    String? presetName = await _showNameInputDialog();
    if (presetName == null || presetName.isEmpty) {
      // Użytkownik anulował lub nie wpisał nazwy
      return;
    }

    setState(() {
      String presetKey = 'custom_${presets.length + 1}';

      presets.add({
        'name': presetName,
        'preset': presetKey,
        'color': color,
      });
    });

    // Wysyłamy żądanie do ESP32, aby ustawić nowy preset
    await _sendRequest('/setPreset', {
      'preset': 'none',
      'r': '${color.red}',
      'g': '${color.green}',
      'b': '${color.blue}',
    });
  }

  Future<String?> _showNameInputDialog() async {
    String presetName = '';
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Nazwa presetu'),
          content: TextField(
            onChanged: (value) {
              presetName = value;
            },
            decoration: InputDecoration(hintText: "Wpisz nazwę presetu"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Anuluj'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(presetName);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildPresetButtons() {
    return Wrap(
      spacing: 10,
      children: [
        ...presets.map((preset) {
          return ElevatedButton(
            onPressed: () => _setPreset(preset['preset']),
            child: Text(preset['name']),
          );
        }).toList(),
        IconButton(
          icon: Icon(Icons.add),
          onPressed: () => _openColorPicker(isPreset: true),
        ),
      ],
    );
  }

  Widget _buildBrightnessSlider() {
    return Row(
      children: [
        Icon(Icons.brightness_6),
        Expanded(
          child: Slider(
            value: _brightness,
            min: 0,
            max: 1,
            divisions: 100,
            onChanged: (value) {
              _setBrightness(value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOnOffSwitch() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0), // Zwiększony odstęp
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Pasek LED'),
          Switch(
            value: _isOn,
            onChanged: (value) {
              _turnOnOff(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfo() {
    return ListTile(
      leading: Icon(Icons.memory),
      title: Text('Połączone urządzenie'),
      subtitle: Text('ESP32 pod adresem $_esp32Ip'),
    );
  }

  Widget _buildCustomColorTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () => _openColorPicker(),
            child: Text('Wybierz kolor'),
          ),
          SizedBox(height: 20),
          Text(
            'Aktualny kolor:',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 10),
          Container(
            width: 100,
            height: 100,
            color: _currentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomLedsTab() {
    // Lista segmentów (12 segmentów po 5 LEDów)
    List<int> segments = List.generate(12, (index) => index);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5, // 5 LEDów w wierszu
                childAspectRatio: 1,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: segments.length,
              itemBuilder: (context, index) {
                Color color = segmentColors[index] ?? Colors.grey;
                return GestureDetector(
                  onTap: () async {
                    Color? pickedColor = await _pickSegmentColor(color);
                    if (pickedColor != null) {
                      setState(() {
                        segmentColors[index] = pickedColor;
                      });
                    }
                  },
                  child: Container(
                    color: color,
                    child: Center(child: Text('Segment ${index + 1}')),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              _applyCustomLeds(segmentColors);
            },
            child: Text('Zatwierdź'),
          ),
        ],
      ),
    );
  }

  Future<Color?> _pickSegmentColor(Color currentColor) async {
    Color pickedColor = currentColor;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Wybierz kolor segmentu'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (Color color) {
              pickedColor = color;
            },
            showLabel: false,
            enableAlpha: false,
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Anuluj'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );

    return pickedColor;
  }

  void _applyCustomLeds(Map<int, Color> segmentColors) {
    // Przygotuj dane do wysłania do ESP32
    List<Map<String, dynamic>> segmentsData = [];

    segmentColors.forEach((segmentIndex, color) {
      segmentsData.add({
        'segment': segmentIndex,
        'r': color.red,
        'g': color.green,
        'b': color.blue,
      });
    });

    // Wysyłanie danych do ESP32
    _sendCustomLedsToEsp32(segmentsData);
  }

  Future<void> _sendCustomLedsToEsp32(
      List<Map<String, dynamic>> segmentsData) async {
    // Serializuj dane do JSON
    String jsonData = jsonEncode(segmentsData);

    // Wysyłanie żądania POST do ESP32
    final url = Uri.http(_esp32Ip, '/setCustomLeds');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonData,
      );
      print('Odpowiedź: ${response.body}');
    } catch (e) {
      print('Błąd: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('LED Controller'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Presety'),
            Tab(text: 'Custom color'),
            Tab(text: 'Custom LEDs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Zakładka Presety
          SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDeviceInfo(),
                _buildOnOffSwitch(),
                _buildBrightnessSlider(),
                SizedBox(height: 20),
                Text('Presety'),
                SizedBox(height: 10),
                _buildPresetButtons(),
              ],
            ),
          ),
          // Zakładka Custom color
          _buildCustomColorTab(),
          // Zakładka Custom LEDs
          _buildCustomLedsTab(),
        ],
      ),
    );
  }
}
