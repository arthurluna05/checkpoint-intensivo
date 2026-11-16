import 'package:flutter/foundation.dart';

import '../../data/repositories/visita_repository.dart';
import '../../data/sync/sincronizador.dart';
import '../../domain/models/status_visita.dart';
import '../../domain/models/visita.dart';

/// Estado da lista de visitas.
/// A interface conversa com o repositório e observa o sincronizador.
class VisitasViewModel extends ChangeNotifier {
  VisitasViewModel(this._repo, this._sync) {
    _sync.addListener(_aoMudarSincronizacao);
    carregar();
  }

  final VisitaRepository _repo;
  final Sincronizador _sync;

  List<Visita> visitas = const [];
  bool carregando = true;
  String? erro;

  int _ultimaVersaoDados = 0;
  bool _descartado = false;

  void _aoMudarSincronizacao() {
    if (_descartado) return;

    if (_ultimaVersaoDados != _sync.versaoDados) {
      _ultimaVersaoDados = _sync.versaoDados;
      carregar();
      return;
    }

    notifyListeners();
  }

  Future<void> carregar() async {
    try {
      final resultado = await _repo.listar();

      if (_descartado) return;

      visitas = resultado;
      erro = null;
    } on Exception {
      if (_descartado) return;

      erro = 'Não foi possível ler as visitas do aparelho.';
    }

    if (_descartado) return;

    carregando = false;
    notifyListeners();
  }

  Future<void> criar({
    required String titulo,
    required String cliente,
    required String endereco,
    required DateTime agendadaPara,
    required StatusVisita status,
    String? observacoes,
  }) async {
    await _repo.criar(
      titulo: titulo,
      cliente: cliente,
      endereco: endereco,
      agendadaPara: agendadaPara,
      status: status,
      observacoes: observacoes,
    );

    await carregar();
  }

  Future<void> atualizar(Visita visita) async {
    await _repo.atualizar(visita);
    await carregar();
  }

  Future<void> excluir(Visita visita) async {
    // Remove da tela imediatamente para satisfazer o Dismissible.
    visitas = visitas.where((item) => item.id != visita.id).toList();
    notifyListeners();

    await _repo.excluir(visita);
    await carregar();
  }

  Future<void> sincronizarAgora() async {
    await _sync.sincronizar();
    await carregar();
  }

  @override
  void dispose() {
    _descartado = true;
    _sync.removeListener(_aoMudarSincronizacao);
    super.dispose();
  }
}
