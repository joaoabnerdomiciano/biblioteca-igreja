import 'package:cloud_firestore/cloud_firestore.dart';

typedef Doc = DocumentSnapshot<Map<String, dynamic>>;

const categorias = [
  'Bíblias',
  'Teologia',
  'Devocionais',
  'Biografias cristãs',
  'Família e casamento',
  'Infantil',
  'Juvenil',
  'Estudos bíblicos',
  'Ficção cristã',
  'Outros',
];

/// Origem de cada exemplar.
const origens = {
  'comprado': 'Comprado',
  'doado': 'Doado',
  'cedido': 'Cedido',
};

/// Situação de cada exemplar.
const statusExemplar = {
  'disponivel': 'Disponível',
  'emprestado': 'Emprestado',
  'reparo': 'Em reparo',
  'devolvido_dono': 'Devolvido ao dono',
  'baixado': 'Retirado do acervo',
};

DateTime? _dt(dynamic v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);
String _s(dynamic v) => v?.toString() ?? '';
int _i(dynamic v) => (v is num) ? v.toInt() : 0;

class Livro {
  final String id;
  String titulo, autor, editora, isbn, categoria, estante, sinopse, capaUrl;
  int? ano;
  bool temFoto, destaque;
  String destaqueNota;
  int total, disponiveis;
  DateTime? criadoEm;

  Livro({
    required this.id,
    this.titulo = '',
    this.autor = '',
    this.editora = '',
    this.isbn = '',
    this.categoria = 'Outros',
    this.estante = '',
    this.sinopse = '',
    this.capaUrl = '',
    this.ano,
    this.temFoto = false,
    this.destaque = false,
    this.destaqueNota = '',
    this.total = 0,
    this.disponiveis = 0,
    this.criadoEm,
  });

  factory Livro.fromDoc(Doc d) {
    final m = d.data() ?? {};
    return Livro(
      id: d.id,
      titulo: _s(m['titulo']),
      autor: _s(m['autor']),
      editora: _s(m['editora']),
      isbn: _s(m['isbn']),
      categoria: m['categoria'] == null ? 'Outros' : _s(m['categoria']),
      estante: _s(m['estante']),
      sinopse: _s(m['sinopse']),
      capaUrl: _s(m['capaUrl']),
      ano: m['ano'] is num ? (m['ano'] as num).toInt() : null,
      temFoto: m['temFoto'] == true,
      destaque: m['destaque'] == true,
      destaqueNota: _s(m['destaqueNota']),
      total: _i(m['total']),
      disponiveis: _i(m['disponiveis']),
      criadoEm: _dt(m['criadoEm']),
    );
  }

  /// Campos que a tela de edição pode alterar (não mexe nos contadores).
  Map<String, dynamic> camposEditaveis() => {
        'titulo': titulo.trim(),
        'autor': autor.trim(),
        'editora': editora.trim(),
        'isbn': isbn.trim(),
        'categoria': categoria,
        'estante': estante.trim(),
        'sinopse': sinopse.trim(),
        'capaUrl': capaUrl.trim(),
        'ano': ano,
        'destaque': destaque,
        'destaqueNota': destaqueNota.trim(),
      };
}

class Exemplar {
  final String id;
  String livroId, codigo, origem, origemNome, status, obs;
  DateTime? criadoEm;

  Exemplar({
    required this.id,
    required this.livroId,
    required this.codigo,
    this.origem = 'comprado',
    this.origemNome = '',
    this.status = 'disponivel',
    this.obs = '',
    this.criadoEm,
  });

  factory Exemplar.fromDoc(Doc d) {
    final m = d.data() ?? {};
    return Exemplar(
      id: d.id,
      livroId: _s(m['livroId']),
      codigo: _s(m['codigo']),
      origem: m['origem'] == null ? 'comprado' : _s(m['origem']),
      origemNome: _s(m['origemNome']),
      status: m['status'] == null ? 'disponivel' : _s(m['status']),
      obs: _s(m['obs']),
      criadoEm: _dt(m['criadoEm']),
    );
  }

  /// Ex.: "Doado por João" / "Cedido por Maria" / "Comprado".
  String get origemTexto {
    final base = origens[origem] ?? origem;
    if (origemNome.trim().isEmpty) return base;
    return '$base por ${origemNome.trim()}';
  }

  /// Exemplares que ainda fazem parte do acervo.
  bool get noAcervo => status == 'disponivel' || status == 'emprestado' || status == 'reparo';
}

class Leitor {
  final String id;
  String nome, telefone, email, grupo, responsavelId, obs;
  DateTime? consentimentoEm, criadoEm;

  Leitor({
    required this.id,
    this.nome = '',
    this.telefone = '',
    this.email = '',
    this.grupo = '',
    this.responsavelId = '',
    this.obs = '',
    this.consentimentoEm,
    this.criadoEm,
  });

  bool get menor => responsavelId.isNotEmpty;

  factory Leitor.fromDoc(Doc d) {
    final m = d.data() ?? {};
    return Leitor(
      id: d.id,
      nome: _s(m['nome']),
      telefone: _s(m['telefone']),
      email: _s(m['email']),
      grupo: _s(m['grupo']),
      responsavelId: _s(m['responsavelId']),
      obs: _s(m['obs']),
      consentimentoEm: _dt(m['consentimentoEm']),
      criadoEm: _dt(m['criadoEm']),
    );
  }

  Map<String, dynamic> campos() => {
        'nome': nome.trim(),
        'telefone': telefone.trim(),
        'email': email.trim(),
        'grupo': grupo.trim(),
        'responsavelId': responsavelId,
        'obs': obs.trim(),
        'consentimentoEm': consentimentoEm,
      };
}

class Emprestimo {
  final String id;
  String exemplarId, exemplarCodigo, livroId, livroTitulo, leitorId, registradoPor, devolvidoPor;
  DateTime? retiradaEm, prevista, devolvidoEm, lembreteEm;
  int renovacoes;
  bool ativo;

  Emprestimo({
    required this.id,
    this.exemplarId = '',
    this.exemplarCodigo = '',
    this.livroId = '',
    this.livroTitulo = '',
    this.leitorId = '',
    this.registradoPor = '',
    this.devolvidoPor = '',
    this.retiradaEm,
    this.prevista,
    this.devolvidoEm,
    this.lembreteEm,
    this.renovacoes = 0,
    this.ativo = false,
  });

  factory Emprestimo.fromDoc(Doc d) {
    final m = d.data() ?? {};
    return Emprestimo(
      id: d.id,
      exemplarId: _s(m['exemplarId']),
      exemplarCodigo: _s(m['exemplarCodigo']),
      livroId: _s(m['livroId']),
      livroTitulo: _s(m['livroTitulo']),
      leitorId: _s(m['leitorId']),
      registradoPor: _s(m['registradoPor']),
      devolvidoPor: _s(m['devolvidoPor']),
      retiradaEm: _dt(m['retiradaEm']),
      prevista: _dt(m['prevista']),
      devolvidoEm: _dt(m['devolvidoEm']),
      lembreteEm: _dt(m['lembreteEm']),
      renovacoes: _i(m['renovacoes']),
      ativo: m['ativo'] == true,
    );
  }
}

class Reserva {
  final String id;
  String livroId, leitorId, status;
  DateTime? criadaEm, avisadoEm;

  Reserva({
    required this.id,
    this.livroId = '',
    this.leitorId = '',
    this.status = 'aguardando',
    this.criadaEm,
    this.avisadoEm,
  });

  bool get ativa => status == 'aguardando' || status == 'avisado';

  factory Reserva.fromDoc(Doc d) {
    final m = d.data() ?? {};
    return Reserva(
      id: d.id,
      livroId: _s(m['livroId']),
      leitorId: _s(m['leitorId']),
      status: m['status'] == null ? 'aguardando' : _s(m['status']),
      criadaEm: _dt(m['criadaEm']),
      avisadoEm: _dt(m['avisadoEm']),
    );
  }
}

class Config {
  String nomeBiblioteca;
  int prazoDias, renovacoes, limite;
  String msgAtraso, msgFila;

  Config({
    this.nomeBiblioteca = 'Biblioteca da Igreja',
    this.prazoDias = 14,
    this.renovacoes = 1,
    this.limite = 2,
    this.msgAtraso = msgAtrasoPadrao,
    this.msgFila = msgFilaPadrao,
  });

  static const msgAtrasoPadrao =
      'Olá, {nome}! Tudo bem? 😊 Passando para lembrar com carinho do livro {livro}, '
      'que estava previsto para voltar em {data}. Quando puder, traga na biblioteca da igreja. '
      'Se quiser ficar mais um tempo com ele, é só avisar que a gente renova. Deus abençoe!';

  static const msgFilaPadrao =
      'Olá, {nome}! Boa notícia: o livro {livro} que você estava esperando já está disponível '
      'na biblioteca da igreja. 📚 Quando vier à igreja, é só procurar a equipe da biblioteca. Deus abençoe!';

  factory Config.fromMap(Map<String, dynamic>? dados) {
    final Map<String, dynamic> m = dados ?? {};
    int n(String k, int padrao) => (m[k] is num && (m[k] as num) > 0) ? (m[k] as num).toInt() : padrao;
    String t(String k, String padrao) => (m[k] is String && (m[k] as String).trim().isNotEmpty) ? m[k] as String : padrao;
    return Config(
      nomeBiblioteca: t('nomeBiblioteca', 'Biblioteca da Igreja'),
      prazoDias: n('prazoDias', 14),
      renovacoes: (m['renovacoes'] is num) ? (m['renovacoes'] as num).toInt() : 1,
      limite: n('limite', 2),
      msgAtraso: t('msgAtraso', msgAtrasoPadrao),
      msgFila: t('msgFila', msgFilaPadrao),
    );
  }

  Map<String, dynamic> toMap() => {
        'nomeBiblioteca': nomeBiblioteca,
        'prazoDias': prazoDias,
        'renovacoes': renovacoes,
        'limite': limite,
        'msgAtraso': msgAtraso,
        'msgFila': msgFila,
      };
}
