import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';
import 'login_page.dart';

void main() async {
  // Garantindo que todos os bindings do Flutter estejam inicializados antes de rodar o app
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializando o Firebase com as opções definidas em firebase_options.dart
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Rodando o aplicativo Flutter
  runApp(const MyApp());
}

// Classe principal do aplicativo
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo', // Título do app
      theme: ThemeData.light(), // Tema claro
      home: const LoginPage(), // Página inicial: LoginPage
    );
  }
}

// Página principal de exemplo após o login
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.ref();
  String userName = 'Usuário';

  @override
  void initState() {
    super.initState();
    _loadUserData(); // Carrega os dados do usuário autenticado
  }

  // Função para carregar o nome do usuário autenticado no Firebase
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Sem cor de fundo
        elevation: 0, // Sem sombra
        title: Text(
          widget.title, // Título da página
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true, // Título centralizado
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            // Retorna à página de login
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
          },
        ),
        actions: [
          // Exibe o nome do usuário no canto superior direito
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.blueAccent),
                  const SizedBox(width: 5),
                  Text(
                    userName,
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // Corpo da página: exibe apenas uma mensagem de boas-vindas
      body: Center(
        child: Text(
          "Bem vindo, $userName!",
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
