// A "loja" guarda em memória todos os dados da biblioteca e os mantém
// sincronizados com o Firestore em tempo real. Como o acervo é pequeno
// (centenas de livros), carregar tudo deixa o app simples e rápido.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'config.dart';
import 'modelos.dart';
import 'util.dart';

final loja = Loja();

class Loja extends ChangeNotifier {
  FirebaseFirestore get db => FirebaseFirestore.instance;

  Map<String, Livro> livros = {};
  Map<String, Exemplar> exemplares = {};
  Map<String, Leitor> leitores = {};
  Map<String, Emprestimo> emprestimos = {};
  Map<String, Reserva> reservas = {};
  List<String> voluntarios = [];
  Config config = Config();

  bool admin = false;
  String? erro;
  final Set<String> _recebidos = {};
  final List<StreamSubscription> _inscricoes = [];
  final Map<String, Future<Uint8List?>> _capas = {};

  static const _colecoes = ['livros', 'exemplares', 'leitores', 'emprestimos', 'reservas'];
  bool get carregado => _colecoes.every(_recebidos.contains);

  String get emailUsuario => FirebaseAuth.instance.currentUser?.email ?? '';

  // ------------------------------------------------------------------
  // Sincronização
  // ------------------------------------------------------------------
  void iniciar({required bool ehAdmin}) {
    parar();
    admin = ehAdmin;
    _ouvir('livros', Livro.fromDoc, (m) => livros = m);
    _ouvir('exemplares', Exemplar.fromDoc, (m) => exemplares = m);
    _ouvir('leitores', Leitor.fromDoc, (m) => leitores = m);
    _ouvir('emprestimos', Emprestimo.fromDoc, (m) => emprestimos = m);
    _ouvir('reservas', Reserva.fromDoc, (m) => reservas = m);
    _inscricoes.add(db.collection('config').doc('geral').snapshots().listen((d) {
      config = Config.fromMap(d.data());
      notifyListeners();
    }, onError: (_) {}));
    if (ehAdmin) {
      _inscricoes.add(db.collection('voluntarios').snapshots().listen((s) {
        voluntarios = s.docs.map((d) => d.id).toList()..sort();
        notifyListeners();
      }, onError: (_) {}));
    }
  }

  void _ouvir<T>(String colecao, T Function(Doc) conv, void Function(Map<String, T>) guardar) {
    _inscricoes.add(db.collection(colecao).snapshots().listen((s) {
      guardar({for (final d in s.docs) d.id: conv(d)});
      _recebidos.add(colecao);
      erro = null;
      notifyListeners();
    }, onError: (e) {
      erro = mensagemDeErro(e);
      notifyListeners();
    }));
  }

  void parar() {
    for (final s in _inscricoes) {
      s.cancel();
    }
    _inscricoes.clear();
    _recebidos.clear();
    _capas.clear();
    livros = {};
    exemplares = {};
    leitores = {};
    emprestimos = {};
    reservas = {};
    voluntarios = [];
  }

  // ------------------------------------------------------------------
  // Consultas (calculadas em memória)
  // ------------------------------------------------------------------
  List<Livro> get livrosOrdenados =>
      livros.values.toList()..sort((a, b) => normalizar(a.titulo).compareTo(normalizar(b.titulo)));

  List<Leitor> get leitoresOrdenados =>
      leitores.values.toList()..sort((a, b) => normalizar(a.nome).compareTo(normalizar(b.nome)));

  List<Emprestimo> get emprestimosAtivos =>
      emprestimos.values.where((e) => e.ativo).toList()
        ..sort((a, b) => (a.prevista ?? DateTime(2100)).compareTo(b.prevista ?? DateTime(2100)));

  bool atrasado(Emprestimo e) => e.ativo && e.prevista != null && soData(e.prevista!).isBefore(hoje());

  List<Emprestimo> get atrasados => emprestimosAtivos.where(atrasado).toList();

  List<Emprestimo> ativosDoLeitor(String leitorId) =>
      emprestimosAtivos.where((e) => e.leitorId == leitorId).toList();

  List<Emprestimo> historicoDoLeitor(String leitorId) =>
      emprestimos.values.where((e) => e.leitorId == leitorId).toList()
        ..sort((a, b) => (b.retiradaEm ?? DateTime(0)).compareTo(a.retiradaEm ?? DateTime(0)));

  List<Emprestimo> historicoDoLivro(String livroId) =>
      emprestimos.values.where((e) => e.livroId == livroId).toList()
        ..sort((a, b) => (b.retiradaEm ?? DateTime(0)).compareTo(a.retiradaEm ?? DateTime(0)));

  Emprestimo? emprestimoDoExemplar(String exemplarId) {
    for (final e in emprestimos.values) {
      if (e.ativo && e.exemplarId == exemplarId) return e;
    }
    return null;
  }

  List<Exemplar> exemplaresDoLivro(String livroId) =>
      exemplares.values.where((e) => e.livroId == livroId).toList()..sort((a, b) => a.codigo.compareTo(b.codigo));

  List<Exemplar> get exemplaresDisponiveis =>
      exemplares.values.where((e) => e.status == 'disponivel' && livros.containsKey(e.livroId)).toList()
        ..sort((a, b) => normalizar(livros[a.livroId]!.titulo).compareTo(normalizar(livros[b.livroId]!.titulo)));

  /// Fila de espera ativa de um livro, por ordem de chegada.
  List<Reserva> filaDoLivro(String livroId) =>
      reservas.values.where((r) => r.livroId == livroId && r.ativa).toList()
        ..sort((a, b) => (a.criadaEm ?? DateTime(0)).compareTo(b.criadaEm ?? DateTime(0)));

  List<Reserva> reservasDoLeitor(String leitorId) =>
      reservas.values.where((r) => r.leitorId == leitorId && r.ativa).toList();

  List<Reserva> get reservasAtivas =>
      reservas.values.where((r) => r.ativa).toList()
        ..sort((a, b) => (a.criadaEm ?? DateTime(0)).compareTo(b.criadaEm ?? DateTime(0)));

  List<Leitor> dependentes(String leitorId) =>
      leitores.values.where((l) => l.responsavelId == leitorId).toList();

  String nomeLeitor(String id) => leitores[id]?.nome ?? 'Leitor removido';

  String tituloLivro(String id, [String reserva = '']) =>
      livros[id]?.titulo ?? (reserva.isNotEmpty ? reserva : 'Livro removido');

  /// Para quem enviar a mensagem: o próprio leitor ou, se for criança, o responsável.
  ({String nome, String telefone, Leitor? crianca}) contato(Leitor l) {
    if (l.menor) {
      final r = leitores[l.responsavelId];
      if (r != null) {
        return (nome: r.nome, telefone: l.telefone.isNotEmpty ? l.telefone : r.telefone, crianca: l);
      }
    }
    return (nome: l.nome, telefone: l.telefone, crianca: null);
  }

  /// Monta a mensagem de WhatsApp a partir de um modelo das configurações.
  ({String telefone, String texto}) mensagem(String modelo, Leitor l, String tituloLivro, {DateTime? data}) {
    final c = contato(l);
    var livro = '"$tituloLivro"';
    if (c.crianca != null) livro += ' (que ${primeiroNome(c.crianca!.nome)} pegou)';
    final texto = preencherModelo(modelo, {
      'nome': primeiroNome(c.nome),
      'livro': livro,
      'data': fmtData(data),
    });
    return (telefone: c.telefone, texto: texto);
  }

  // ------------------------------------------------------------------
  // Empréstimos
  // ------------------------------------------------------------------
  Future<Emprestimo> emprestar(Leitor leitor, Exemplar exemplar) async {
    if (ativosDoLeitor(leitor.id).length >= config.limite) {
      throw AvisoErro('${primeiroNome(leitor.nome)} já está com ${config.limite} livros.');
    }
    final empRef = db.collection('emprestimos').doc();
    final exRef = db.collection('exemplares').doc(exemplar.id);
    final livRef = db.collection('livros').doc(exemplar.livroId);
    final prevista = hoje().add(Duration(days: config.prazoDias));
    final dados = {
      'exemplarId': exemplar.id,
      'exemplarCodigo': exemplar.codigo,
      'livroId': exemplar.livroId,
      'livroTitulo': tituloLivro(exemplar.livroId),
      'leitorId': leitor.id,
      'retiradaEm': DateTime.now(),
      'prevista': prevista,
      'devolvidoEm': null,
      'renovacoes': 0,
      'ativo': true,
      'registradoPor': emailUsuario,
    };
    final ok = await db.runTransaction<bool>((tx) async {
      final ex = await tx.get(exRef);
      if (!ex.exists || ex.data()?['status'] != 'disponivel') return false;
      tx.set(empRef, dados);
      tx.update(exRef, {'status': 'emprestado'});
      tx.update(livRef, {'disponiveis': FieldValue.increment(-1)});
      return true;
    });
    if (!ok) throw AvisoErro('Este exemplar não está mais disponível.');

    // Se a pessoa estava na fila deste livro, a reserva foi atendida.
    for (final r in filaDoLivro(exemplar.livroId).where((r) => r.leitorId == leitor.id)) {
      await db.collection('reservas').doc(r.id).update({'status': 'atendida'});
    }
    return Emprestimo(
        id: empRef.id,
        exemplarCodigo: exemplar.codigo,
        livroId: exemplar.livroId,
        livroTitulo: dados['livroTitulo'] as String,
        leitorId: leitor.id,
        prevista: prevista,
        ativo: true);
  }

  Future<void> devolver(Emprestimo e) async {
    final empRef = db.collection('emprestimos').doc(e.id);
    final exRef = db.collection('exemplares').doc(e.exemplarId);
    final livRef = db.collection('livros').doc(e.livroId);
    final livroExiste = livros.containsKey(e.livroId);
    final ok = await db.runTransaction<bool>((tx) async {
      final emp = await tx.get(empRef);
      final ex = await tx.get(exRef);
      if (!emp.exists || emp.data()?['ativo'] != true) return false;
      tx.update(empRef, {'ativo': false, 'devolvidoEm': DateTime.now(), 'devolvidoPor': emailUsuario});
      if (ex.exists && ex.data()?['status'] == 'emprestado') {
        tx.update(exRef, {'status': 'disponivel'});
        if (livroExiste) tx.update(livRef, {'disponiveis': FieldValue.increment(1)});
      }
      return true;
    });
    if (!ok) throw AvisoErro('Este empréstimo já tinha sido devolvido.');
  }

  bool podeRenovar(Emprestimo e) => e.ativo && e.renovacoes < config.renovacoes;

  Future<DateTime> renovar(Emprestimo e) async {
    if (!podeRenovar(e)) throw AvisoErro('Este empréstimo já foi renovado o máximo de vezes.');
    final base = (e.prevista != null && e.prevista!.isAfter(hoje())) ? soData(e.prevista!) : hoje();
    final nova = base.add(Duration(days: config.prazoDias));
    await db.collection('emprestimos').doc(e.id).update({
      'prevista': nova,
      'renovacoes': FieldValue.increment(1),
    });
    return nova;
  }

  Future<void> marcarLembrete(Emprestimo e) =>
      db.collection('emprestimos').doc(e.id).update({'lembreteEm': DateTime.now()});

  // ------------------------------------------------------------------
  // Reservas
  // ------------------------------------------------------------------
  Future<void> reservar(String livroId, String leitorId) async {
    if (filaDoLivro(livroId).any((r) => r.leitorId == leitorId)) {
      throw AvisoErro('Esta pessoa já está na fila deste livro.');
    }
    await db.collection('reservas').add({
      'livroId': livroId,
      'leitorId': leitorId,
      'status': 'aguardando',
      'criadaEm': DateTime.now(),
    });
  }

  Future<void> marcarAvisado(Reserva r) =>
      db.collection('reservas').doc(r.id).update({'status': 'avisado', 'avisadoEm': DateTime.now()});

  Future<void> cancelarReserva(Reserva r) => db.collection('reservas').doc(r.id).update({'status': 'cancelada'});

  // ------------------------------------------------------------------
  // Acervo
  // ------------------------------------------------------------------
  String novoId(String colecao) => db.collection(colecao).doc().id;

  Future<void> criarLivro(Livro l, {required int quantidade, required String origem, String origemNome = ''}) async {
    await db.collection('livros').doc(l.id).set({
      ...l.camposEditaveis(),
      'temFoto': false,
      'total': 0,
      'disponiveis': 0,
      'criadoEm': DateTime.now(),
    });
    if (quantidade > 0) await adicionarExemplares(l.id, quantidade, origem, origemNome);
  }

  Future<void> atualizarLivro(Livro l) => db.collection('livros').doc(l.id).update(l.camposEditaveis());

  Future<void> definirDestaque(Livro l, bool destaque, String nota) =>
      db.collection('livros').doc(l.id).update({'destaque': destaque, 'destaqueNota': nota.trim()});

  /// Cria exemplares com códigos BIB-0001, BIB-0002... em sequência.
  Future<List<String>> adicionarExemplares(String livroId, int qtd, String origem, String origemNome) {
    final contRef = db.collection('config').doc('contadores');
    final livRef = db.collection('livros').doc(livroId);
    return db.runTransaction<List<String>>((tx) async {
      final c = await tx.get(contRef);
      var prox = (c.data()?['proximoExemplar'] as num?)?.toInt() ?? 1;
      final codigos = <String>[];
      for (var i = 0; i < qtd; i++) {
        final codigo = 'BIB-${prox.toString().padLeft(4, '0')}';
        prox++;
        tx.set(db.collection('exemplares').doc(), {
          'livroId': livroId,
          'codigo': codigo,
          'origem': origem,
          'origemNome': origemNome.trim(),
          'status': 'disponivel',
          'criadoEm': DateTime.now(),
        });
        codigos.add(codigo);
      }
      tx.set(contRef, {'proximoExemplar': prox}, SetOptions(merge: true));
      tx.update(livRef, {'total': FieldValue.increment(qtd), 'disponiveis': FieldValue.increment(qtd)});
      return codigos;
    });
  }

  static (int, int) _peso(String status) => switch (status) {
        'disponivel' => (1, 1),
        'emprestado' || 'reparo' => (1, 0),
        _ => (0, 0),
      };

  Future<void> mudarStatusExemplar(Exemplar e, String novo) async {
    if (e.status == 'emprestado') throw AvisoErro('Registre a devolução antes de mudar a situação.');
    if (novo == 'emprestado') throw AvisoErro('Use a tela de empréstimo para emprestar.');
    final (t0, d0) = _peso(e.status);
    final (t1, d1) = _peso(novo);
    final b = db.batch();
    b.update(db.collection('exemplares').doc(e.id), {'status': novo});
    b.update(db.collection('livros').doc(e.livroId),
        {'total': FieldValue.increment(t1 - t0), 'disponiveis': FieldValue.increment(d1 - d0)});
    await b.commit();
  }

  Future<void> excluirExemplar(Exemplar e) async {
    if (!admin) throw AvisoErro('Só o administrador pode excluir.');
    if (e.status == 'emprestado') throw AvisoErro('Este exemplar está emprestado.');
    final (t, d) = _peso(e.status);
    final b = db.batch();
    b.delete(db.collection('exemplares').doc(e.id));
    b.update(db.collection('livros').doc(e.livroId),
        {'total': FieldValue.increment(-t), 'disponiveis': FieldValue.increment(-d)});
    await b.commit();
  }

  Future<void> excluirLivro(Livro l) async {
    if (!admin) throw AvisoErro('Só o administrador pode excluir livros.');
    final exs = exemplaresDoLivro(l.id);
    if (exs.any((e) => e.status == 'emprestado')) {
      throw AvisoErro('Há exemplares deste livro emprestados. Registre a devolução primeiro.');
    }
    final b = db.batch();
    for (final e in exs) {
      b.delete(db.collection('exemplares').doc(e.id));
    }
    for (final r in filaDoLivro(l.id)) {
      b.update(db.collection('reservas').doc(r.id), {'status': 'cancelada'});
    }
    b.delete(db.collection('capas').doc(l.id));
    b.delete(db.collection('livros').doc(l.id));
    await b.commit();
  }

  // ------------------------------------------------------------------
  // Capas (fotos tiradas no app, guardadas reduzidas no próprio banco)
  // ------------------------------------------------------------------
  Future<Uint8List?> capa(String livroId) => _capas.putIfAbsent(livroId, () async {
        try {
          final d = await db.collection('capas').doc(livroId).get();
          final img = d.data()?['img'];
          return img is String ? base64Decode(img) : null;
        } catch (_) {
          return null;
        }
      });

  Future<void> salvarCapa(String livroId, Uint8List bytes) async {
    if (bytes.length > 700 * 1024) throw AvisoErro('A foto ficou grande demais. Tente de novo mais de perto.');
    await db.collection('capas').doc(livroId).set({'img': base64Encode(bytes)});
    await db.collection('livros').doc(livroId).update({'temFoto': true});
    _capas[livroId] = Future.value(bytes);
  }

  Future<void> removerCapa(String livroId) async {
    await db.collection('capas').doc(livroId).delete();
    await db.collection('livros').doc(livroId).update({'temFoto': false});
    _capas.remove(livroId);
  }

  // ------------------------------------------------------------------
  // Leitores
  // ------------------------------------------------------------------
  Future<void> salvarLeitor(Leitor l, {bool novo = false}) async {
    final ref = db.collection('leitores').doc(l.id);
    if (novo) {
      await ref.set({...l.campos(), 'criadoEm': DateTime.now()});
    } else {
      await ref.update(l.campos());
    }
  }

  /// Exclusão (LGPD): apaga os dados pessoais. Os empréstimos antigos
  /// continuam nas estatísticas como "Leitor removido".
  Future<void> excluirLeitor(Leitor l) async {
    if (!admin) throw AvisoErro('Só o administrador pode excluir leitores.');
    if (ativosDoLeitor(l.id).isNotEmpty) throw AvisoErro('Esta pessoa ainda está com livros emprestados.');
    if (dependentes(l.id).isNotEmpty) {
      throw AvisoErro('Esta pessoa é responsável por crianças cadastradas. Exclua ou altere esses cadastros antes.');
    }
    final b = db.batch();
    for (final r in reservas.values.where((r) => r.leitorId == l.id)) {
      b.delete(db.collection('reservas').doc(r.id));
    }
    b.delete(db.collection('leitores').doc(l.id));
    await b.commit();
  }

  // ------------------------------------------------------------------
  // Administração
  // ------------------------------------------------------------------
  Future<void> salvarConfig(Config c) => db.collection('config').doc('geral').set(c.toMap());

  Future<void> adicionarVoluntario(String email) {
    final e = email.trim().toLowerCase();
    if (!e.contains('@')) throw AvisoErro('E-mail inválido.');
    return db.collection('voluntarios').doc(e).set({'adicionadoEm': DateTime.now()});
  }

  Future<void> removerVoluntario(String email) => db.collection('voluntarios').doc(email).delete();

  static bool ehAdministrador(String? email) =>
      email != null && email.trim().toLowerCase() == emailAdministrador.trim().toLowerCase();
}
