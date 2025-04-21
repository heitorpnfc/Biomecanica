import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.ref();
  String userName = 'Usuário';
  bool? isConnected;

  // IP do ESP e intervalo de amostragem (ms)
  final String espIP = "192.168.3.19";
  final int aqTime = 100;

  // Timer para chamadas periódicas
  Timer? _timer;

  // Variáveis YPR
  double? yaw, pitch, roll;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _loadUserData() {
    final user = _auth.currentUser;
    if (user != null) {
      _databaseReference
          .child('users/colaboradores')
          .child(user.uid)
          .once()
          .then((event) {
        final snap = event.snapshot;
        setState(() {
          userName = snap.exists
              ? (snap.child('name').value as String? ?? 'Usuário')
              : 'Usuário desconhecido';
        });
      });
    }
  }

  Future<void> _connectToESP() async {
    try {
      final response = await http.get(Uri.parse("http://$espIP/imu1"));
      if (response.statusCode == 200) {
        setState(() => isConnected = true);
        final data = json.decode(response.body) as Map<String, dynamic>;
        setState(() {
          yaw = (data['yaw'] as num).toDouble();
          pitch = (data['pitch'] as num).toDouble();
          roll = (data['roll'] as num).toDouble();
        });
        // Grava no Firebase
        _databaseReference.child("sensor_data").push().set({
          "timestamp": DateTime.now().millisecondsSinceEpoch,
          "yaw": yaw,
          "pitch": pitch,
          "roll": roll,
        });
      } else {
        setState(() => isConnected = false);
      }
    } catch (e) {
      setState(() => isConnected = false);
      debugPrint("Erro ao conectar ao ESP32: $e");
    }
  }

  void _startStreaming() {
    // evita múltiplos timers
    if (_timer != null && _timer!.isActive) return;
    // imediatamente busca uma vez...
    _connectToESP();
    // ...e depois periodicamente
    _timer = Timer.periodic(Duration(milliseconds: aqTime), (_) {
      _connectToESP();
    });
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
                    label: const Text("Conectar ESP",
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
                    const Text(
                      "Dados do Sensor (MPU6050):",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(2)
                      },
                      border: TableBorder.all(color: Colors.black12),
                      children: [
                        buildDataRow("Yaw (°)", yaw),
                        buildDataRow("Pitch (°)", pitch),
                        buildDataRow("Roll (°)", roll),
                      ],
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
