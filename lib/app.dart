import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/auth/auth_service.dart';
import 'data/sessao.dart';
import 'data/sync/sincronizador.dart';
import 'domain/models/usuario.dart';
import 'ui/login/login_page.dart';
import 'ui/login/login_view_model.dart';
import 'ui/visitas/visitas_page.dart';
import 'ui/visitas/visitas_view_model.dart';

class CheckpointApp extends StatelessWidget {
  const CheckpointApp({super.key, required this.auth, required this.firestore});

  final AuthService auth;
  final FirebaseFirestore firestore;

  @override
  Widget build(BuildContext context) {
    const semente = Color(0xFF00408A);

    return MaterialApp(
      title: 'Checkpoint',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: semente),
      darkTheme: ThemeData(
        colorSchemeSeed: semente,
        brightness: Brightness.dark,
      ),
      home: AuthGate(auth: auth, firestore: firestore),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.auth, required this.firestore});

  final AuthService auth;
  final FirebaseFirestore firestore;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<Usuario?>? _assinatura;

  bool _iniciado = false;
  Usuario? _usuario;
  Sessao? _sessao;

  @override
  void initState() {
    super.initState();
    _assinatura = widget.auth.usuario.listen(_aoMudarUsuario);
  }

  Future<void> _aoMudarUsuario(Usuario? usuario) async {
    if (_iniciado && usuario?.uid == _usuario?.uid) {
      return;
    }

    final sessaoAntiga = _sessao;

    setState(() {
      _iniciado = true;
      _usuario = usuario;
      _sessao = null;
    });

    if (sessaoAntiga != null) {
      await WidgetsBinding.instance.endOfFrame;
      await sessaoAntiga.encerrar(apagarDados: true);
    }

    if (usuario == null) {
      return;
    }

    final novaSessao = await Sessao.abrir(usuario, firestore: widget.firestore);

    if (!mounted || _usuario?.uid != usuario.uid) {
      await novaSessao.encerrar(apagarDados: false);
      return;
    }

    setState(() {
      _sessao = novaSessao;
    });

    unawaited(widget.auth.revalidarSessao());
  }

  Future<void> _sair() async {
    final sessao = _sessao;
    if (sessao == null) return;
    final sync = sessao.sincronizador;

    // Última chance de subir o que está pendente.
    if (sync.pendentes > 0) await sync.sincronizar();

    if (sync.pendentes > 0 && mounted) {
      final confirmou = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.warning_amber),
          title: const Text('Há visitas não enviadas'),
          content: Text(
            '${sync.pendentes} visita(s) ainda não chegaram ao '
            'servidor. Se sair agora, elas serão APAGADAS deste aparelho.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ficar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sair e apagar'),
            ),
          ],
        ),
      );
      if (confirmou != true) return;
    }
    await widget.auth.sair(); // o listener cuida de encerrar a sessão
  }

  @override
  Widget build(BuildContext context) {
    if (!_iniciado) {
      return const _Carregando();
    }

    final usuario = _usuario;

    if (usuario == null) {
      return ChangeNotifierProvider(
        create: (_) => LoginViewModel(widget.auth),
        child: const LoginPage(),
      );
    }

    final sessao = _sessao;

    if (sessao == null) {
      return const _Carregando();
    }

    return MultiProvider(
      key: ValueKey(usuario.uid),
      providers: [
        ChangeNotifierProvider<Sincronizador>.value(
          value: sessao.sincronizador,
        ),
        ChangeNotifierProvider(
          create: (_) =>
              VisitasViewModel(sessao.repositorio, sessao.sincronizador),
        ),
      ],
      child: VisitasPage(email: usuario.email, aoSair: _sair),
    );
  }
}

class _Carregando extends StatelessWidget {
  const _Carregando();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
