import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;

import 'login_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IMU Sensor Streaming',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const WelcomePage(),
    );
  }
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // URLs dos dois ESPs
  final String espURL1 = "http://192.168.3.19/imu";
  final String espURL2 = "http://192.168.3.21/imu2";

  // Intervalo de amostragem em ms
  final int aqTime = 10;
  // Intervalo de atualização do ângulo em ms (700 ms)
  final int angleUpdateIntervalMs = 700;

  // Timer para streaming e para ângulo
  Timer? _streamTimer;
  Timer? _angleTimer;

  // Cliente HTTP único
  late final http.Client _client;

  // Dados YPR dos dois sensores
  double? yaw1, pitch1, roll1;
  double? yaw2, pitch2, roll2;

  // Último ângulo calculado
  double? kneeAngle;

  // Nome do usuário
  String userName = 'Usuário';
  bool? isConnected;

  @override
  void initState() {
    super.initState();
    _client = http.Client();
    _loadUserData();
  }

  @override
  void dispose() {
    _streamTimer?.cancel();
    _angleTimer?.cancel();
    _client.close();
    super.dispose();
  }

  void _loadUserData() {
    final user = _auth.currentUser;
    if (user != null) {
      _db.child('users/colaboradores').child(user.uid).once().then((e) {
        setState(() {
          userName = e.snapshot.exists
              ? (e.snapshot.child('name').value as String? ?? 'Usuário')
              : 'Usuário';
        });
      });
    }
  }

  Future<void> _fetchBothIMUs() async {
    try {
      final responses = await Future.wait([
        _client.get(Uri.parse(espURL1)),
        _client.get(Uri.parse(espURL2)),
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final data1 = json.decode(responses[0].body) as Map<String, dynamic>;
        final data2 = json.decode(responses[1].body) as Map<String, dynamic>;

        setState(() {
          yaw1 = (data1['yaw'] as num).toDouble();
          pitch1 = (data1['pitch'] as num).toDouble();
          roll1 = (data1['roll'] as num).toDouble();
          yaw2 = (data2['yaw'] as num).toDouble();
          pitch2 = (data2['pitch'] as num).toDouble();
          roll2 = (data2['roll'] as num).toDouble();
          isConnected = true;
        });

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        _db.child('sensor_data').child('$timestamp').set({
          'yaw1': yaw1,
          'pitch1': pitch1,
          'roll1': roll1,
          'yaw2': yaw2,
          'pitch2': pitch2,
          'roll2': roll2,
        });
      } else {
        setState(() => isConnected = false);
      }
    } catch (e) {
      setState(() => isConnected = false);
      debugPrint('Erro ao buscar IMUs: $e');
    }
  }

  void _startStreaming() {
    if (_streamTimer?.isActive ?? false) return;

    // chama imediatamente
    _fetchBothIMUs();

    // timer periódico de leitura IMU
    _streamTimer = Timer.periodic(
      Duration(milliseconds: aqTime),
      (_) => _fetchBothIMUs(),
    );

    // timer periódico de cálculo de ângulo
    _angleTimer = Timer.periodic(
      Duration(milliseconds: angleUpdateIntervalMs),
      (_) {
        if (pitch1 != null && pitch2 != null) {
          setState(() {
            kneeAngle = (pitch1! - pitch2!).abs();
          });
        }
      },
    );
  }

  Future<void> _logout() async {
    await _auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  TableRow buildDataRow(String label, double? value) {
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(value != null ? value.toStringAsFixed(2) : '---'),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text(
                'Boas Vindas',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              centerTitle: true,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: _logout,
                ),
              ],
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 4))
                  ],
                ),
                child: Column(children: [
                  Text(
                    'Bem vindo, $userName!',
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E1E)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _startStreaming,
                    icon: Icon(
                      isConnected == true ? Icons.check_circle : Icons.cancel,
                      color: isConnected == true ? Colors.green : Colors.red,
                    ),
                    label: const Text("Conectar ESPs",
                        style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (isConnected == true) ...[
                    const Text("Sensor 1 (Coxa):",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(2)
                      },
                      border: TableBorder.all(color: Colors.black12),
                      children: [
                        buildDataRow("Yaw1 (°)", yaw1),
                        buildDataRow("Pitch1 (°)", pitch1),
                        buildDataRow("Roll1 (°)", roll1),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text("Sensor 2 (Canela):",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(2)
                      },
                      border: TableBorder.all(color: Colors.black12),
                      children: [
                        buildDataRow("Yaw2 (°)", yaw2),
                        buildDataRow("Pitch2 (°)", pitch2),
                        buildDataRow("Roll2 (°)", roll2),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text("Ângulo do joelho (°):",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      kneeAngle != null ? kneeAngle!.toStringAsFixed(2) : '---',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
