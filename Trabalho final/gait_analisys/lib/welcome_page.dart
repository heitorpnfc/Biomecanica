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
  // Atualize com o IP do seu ESP32 na rede Wi‑Fi
  final String espIP = "192.168.3.19";

  // Variáveis para os dados do ESP
  double? yaw, pitch, roll, ax, ay, az;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Carrega o nome do usuário a partir do Firebase
  void _loadUserData() {
    User? user = _auth.currentUser;
    if (user != null) {
      _databaseReference
          .child('users/colaboradores')
          .child(user.uid)
          .once()
          .then((DatabaseEvent event) {
        if (event.snapshot.exists) {
          setState(() {
            userName =
                event.snapshot.child('name').value as String? ?? 'Usuário';
          });
        } else {
          setState(() {
            userName = 'Usuário desconhecido';
          });
        }
      });
    }
  }

  // Tenta conectar ao ESP32 via Wi‑Fi através de uma requisição HTTP
  // e envia os dados obtidos para o Firebase criando uma nova linha na tabela "sensor_data"
  Future<void> _connectToESP() async {
    try {
      final response = await http.get(Uri.parse("http://$espIP/imu"));
      if (response.statusCode == 200) {
        setState(() {
          isConnected = true;
        });

        // Parseia os dados JSON
        final data = json.decode(response.body);
        setState(() {
          yaw = data['yaw'];
          pitch = data['pitch'];
          roll = data['roll'];
          ax = data['ax'];
          ay = data['ay'];
          az = data['az'];
        });

        // Cria um registro com os dados do sensor
        final sensorData = {
          "timestamp": DateTime.now().millisecondsSinceEpoch,
          "yaw": yaw,
          "pitch": pitch,
          "roll": roll,
          "ax": ax,
          "ay": ay,
          "az": az,
        };

        // Envia os dados para o Firebase, criando uma nova linha
        _databaseReference.child("sensor_data").push().set(sensorData);
      } else {
        setState(() => isConnected = false);
      }
    } catch (e) {
      setState(() => isConnected = false);
      print("Erro ao conectar ao ESP32: $e");
    }
  }

  // Realiza logout e retorna para a tela de login
  Future<void> _logout() async {
    await _auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  TableRow buildDataRow(String label, double? value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child:
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(value != null ? value.toStringAsFixed(2) : '---'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fundo com gradiente para manter o estilo elegante
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // AppBar customizado (transparente) com botão de logout
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
                    color: Colors.white,
                  ),
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
            // Conteúdo centralizado em card semitransparente
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
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Bem vindo, $userName!',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E1E),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        onPressed: _connectToESP,
                        icon: Icon(
                          isConnected == true
                              ? Icons.check_circle
                              : Icons.cancel,
                          color:
                              isConnected == true ? Colors.green : Colors.red,
                        ),
                        label: const Text(
                          "Conectar ESP",
                          style: TextStyle(fontSize: 18),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      if (isConnected == true)
                        Column(
                          children: [
                            const Text(
                              "Dados do Sensor (MPU6050):",
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 16),
                            Table(
                              columnWidths: const {
                                0: FlexColumnWidth(2),
                                1: FlexColumnWidth(2),
                              },
                              border: TableBorder.all(color: Colors.black12),
                              children: [
                                buildDataRow("Yaw (°)", yaw),
                                buildDataRow("Pitch (°)", pitch),
                                buildDataRow("Roll (°)", roll),
                                buildDataRow("Acel. X (m/s²)", ax),
                                buildDataRow("Acel. Y (m/s²)", ay),
                                buildDataRow("Acel. Z (m/s²)", az),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
