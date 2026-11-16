import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/ambiente.dart';
import 'data/auth/auth_firebase.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carrega as configurações do Firebase.
  final ambiente = Ambiente.atual();

  await Firebase.initializeApp(options: ambiente.firebaseOptions);

  // Inicializa a autenticação.
  final auth = FirebaseAuth.instance;

  // Conecta ao Firebase Authentication Emulator.
  if (ambiente.usarEmulador) {
    debugPrint(
      '[Checkpoint] Auth Emulator: '
      '${ambiente.hostEmulador}:9099',
    );

    await auth.useAuthEmulator(ambiente.hostEmulador, 9099);
  }

  // Inicia o aplicativo Checkpoint.
  runApp(CheckpointApp(auth: AuthFirebase(auth)));
}
