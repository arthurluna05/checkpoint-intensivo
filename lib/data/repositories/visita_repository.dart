import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../domain/models/status_visita.dart';
import '../../domain/models/visita.dart';
import '../local/visita_dao.dart';
import '../sync/sincronizador.dart';

/// Única porta da interface para os dados de visitas.
class VisitaRepository {
  VisitaRepository(this._dao, this._sync, {DateTime Function()? relogio})
    : _relogio = relogio ?? DateTime.now;

  final VisitaDao _dao;
  final Sincronizador _sync;

  static const _uuid = Uuid();
  final DateTime Function() _relogio;

  Future<List<Visita>> listar() => _dao.listar();

  Future<Visita> criar({
    required String titulo,
    required String cliente,
    required String endereco,
    required DateTime agendadaPara,
    StatusVisita status = StatusVisita.agendada,
    String? observacoes,
  }) async {
    final agora = _relogio();

    final visita = Visita(
      id: _uuid.v4(),
      titulo: titulo.trim(),
      cliente: cliente.trim(),
      endereco: endereco.trim(),
      status: status,
      agendadaPara: agendadaPara,
      observacoes: _limpar(observacoes),
      criadaEm: agora,
      atualizadaEm: agora,
    );

    await _dao.salvar(visita);
    await _aposEscrita();

    return visita;
  }

  Future<void> atualizar(Visita visita) async {
    await _dao.salvar(
      visita.copyWith(
        titulo: visita.titulo.trim(),
        cliente: visita.cliente.trim(),
        endereco: visita.endereco.trim(),
        observacoes: () => _limpar(visita.observacoes),
        atualizadaEm: _relogio(),
        sincronizada: false,
      ),
    );

    await _aposEscrita();
  }

  /// Exclusão lógica: a visita será removida definitivamente
  /// depois que a exclusão for enviada ao servidor.
  Future<void> excluir(Visita visita) async {
    await _dao.salvar(
      visita.copyWith(
        excluida: true,
        atualizadaEm: _relogio(),
        sincronizada: false,
      ),
    );

    await _aposEscrita();
  }

  Future<void> _aposEscrita() async {
    await _sync.atualizarPendentes();
    unawaited(_sync.sincronizar());
  }

  static String? _limpar(String? texto) {
    final resultado = texto?.trim();

    if (resultado == null || resultado.isEmpty) {
      return null;
    }

    return resultado;
  }
}
