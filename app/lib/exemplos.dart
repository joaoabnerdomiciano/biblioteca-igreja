// Dados de exemplo para testar o app. Disponível só para o administrador
// e só enquanto o acervo estiver vazio.
import 'package:flutter/material.dart';

import 'componentes.dart';
import 'loja.dart';
import 'util.dart';

const _livros = [
  // título, autor, editora, ano, categoria, estante, exemplares, origem, nome da origem
  ['Bíblia Sagrada — Nova Versão Internacional', '', 'Vida', 2023, 'Bíblias', 'A1', 3, 'comprado', ''],
  ['Bíblia de Estudo NAA', '', 'SBB', 2019, 'Bíblias', 'A1', 1, 'doado', 'Família Souza'],
  ['Cristianismo Puro e Simples', 'C. S. Lewis', 'Thomas Nelson Brasil', 2017, 'Teologia', 'B1', 2, 'comprado', ''],
  ['Conhecendo Deus', 'J. I. Packer', 'Cultura Cristã', 2014, 'Teologia', 'B1', 1, 'cedido', 'Pr. Marcos'],
  ['O Deus Pródigo', 'Timothy Keller', 'Thomas Nelson Brasil', 2018, 'Teologia', 'B2', 1, 'comprado', ''],
  ['Mananciais no Deserto', 'L. B. Cowman', 'Betânia', 2010, 'Devocionais', 'C1', 2, 'doado', ''],
  ['Tudo Para Ele', 'Oswald Chambers', 'Publicações Pão Diário', 2016, 'Devocionais', 'C1', 1, 'comprado', ''],
  ['O Refúgio Secreto', 'Corrie ten Boom', 'Betânia', 2015, 'Biografias cristãs', 'C2', 1, 'doado', 'Irmã Lúcia'],
  ['Hudson Taylor e a Missão na China', 'Howard Taylor', 'Mundo Cristão', 2009, 'Biografias cristãs', 'C2', 1, 'comprado', ''],
  ['As Cinco Linguagens do Amor', 'Gary Chapman', 'Mundo Cristão', 2013, 'Família e casamento', 'D1', 2, 'comprado', ''],
  ['O Significado do Casamento', 'Timothy Keller', 'Vida Nova', 2012, 'Família e casamento', 'D1', 1, 'cedido', 'Ana e Paulo'],
  ['A Bíblia em 365 Histórias', 'Mary Batchelor', 'Paulus', 2011, 'Infantil', 'E1', 2, 'doado', ''],
  ['Meu Primeiro Livro de Orações', '', 'Sociedade Bíblica', 2020, 'Infantil', 'E1', 1, 'comprado', ''],
  ['O Leão, a Feiticeira e o Guarda-Roupa', 'C. S. Lewis', 'WMF Martins Fontes', 2009, 'Juvenil', 'E2', 2, 'comprado', ''],
  ['Como Ler a Bíblia Livro por Livro', 'Gordon Fee e Douglas Stuart', 'Vida Nova', 2013, 'Estudos bíblicos', 'F1', 1, 'comprado', ''],
  ['Entendes o que Lês?', 'Gordon Fee e Douglas Stuart', 'Vida Nova', 2011, 'Estudos bíblicos', 'F1', 1, 'doado', ''],
  ['O Peregrino', 'John Bunyan', 'Mundo Cristão', 2012, 'Ficção cristã', 'G1', 2, 'comprado', ''],
  ['Cartas de um Diabo a seu Aprendiz', 'C. S. Lewis', 'Thomas Nelson Brasil', 2017, 'Ficção cristã', 'G1', 1, 'comprado', ''],
  ['Em Seus Passos o que Faria Jesus?', 'Charles M. Sheldon', 'Mundo Cristão', 2009, 'Ficção cristã', 'G1', 1, 'doado', ''],
  ['Ben-Hur', 'Lew Wallace', 'Principis', 2020, 'Outros', 'G2', 1, 'comprado', ''],
];

const _leitores = [
  // nome, telefone, grupo, índice do responsável (-1 = adulto)
  ['Maria Aparecida Santos', '(11) 90000-0001', 'Intercessão', -1],
  ['João Pedro Oliveira', '(11) 90000-0002', 'Jovens', -1],
  ['Ana Clara Ferreira', '(11) 90000-0003', 'Louvor', -1],
  ['Carlos Eduardo Lima', '(11) 90000-0004', 'Diaconia', -1],
  ['Fernanda Costa', '(11) 90000-0005', 'EBD', -1],
  ['Roberto Almeida', '(11) 90000-0006', '', -1],
  ['Lucas Ferreira', '', 'Kids', 2],
  ['Sofia Costa', '', 'Kids', 4],
];

Future<void> carregarExemplos() async {
  if (loja.livros.isNotEmpty) throw AvisoErro('O acervo já tem livros. Os exemplos só podem ser carregados com ele vazio.');
  final db = loja.db;
  final b = db.batch();
  final agora = DateTime.now();
  var codigo = 1;

  final livroIds = <String>[];
  final exemplaresPorLivro = <List<(String, String)>>[]; // (id, código)
  for (final l in _livros) {
    final id = loja.novoId('livros');
    livroIds.add(id);
    final qtd = l[6] as int;
    b.set(db.collection('livros').doc(id), {
      'titulo': l[0], 'autor': l[1], 'editora': l[2], 'ano': l[3], 'isbn': '', 'categoria': l[4], 'estante': l[5],
      'sinopse': '', 'capaUrl': '', 'temFoto': false, 'destaque': false, 'destaqueNota': '',
      'total': qtd, 'disponiveis': qtd, 'criadoEm': agora,
    });
    final lista = <(String, String)>[];
    for (var i = 0; i < qtd; i++) {
      final exId = loja.novoId('exemplares');
      final cod = 'BIB-${(codigo++).toString().padLeft(4, '0')}';
      lista.add((exId, cod));
      b.set(db.collection('exemplares').doc(exId), {
        'livroId': id, 'codigo': cod, 'origem': l[7], 'origemNome': l[8], 'status': 'disponivel', 'criadoEm': agora,
      });
    }
    exemplaresPorLivro.add(lista);
  }

  final leitorIds = List.generate(_leitores.length, (_) => loja.novoId('leitores'));
  for (var i = 0; i < _leitores.length; i++) {
    final p = _leitores[i];
    final resp = p[3] as int;
    b.set(db.collection('leitores').doc(leitorIds[i]), {
      'nome': p[0], 'telefone': p[1], 'email': '', 'grupo': p[2], 'obs': 'Cadastro de exemplo',
      'responsavelId': resp >= 0 ? leitorIds[resp] : '', 'consentimentoEm': agora, 'criadoEm': agora,
    });
  }

  // Destaques do mês
  b.update(db.collection('livros').doc(livroIds[2]), {'destaque': true, 'destaqueNota': 'Indicação do pastor para este mês'});
  b.update(db.collection('livros').doc(livroIds[9]), {'destaque': true, 'destaqueNota': 'Para o mês da família'});

  final h = hoje();
  void emprestimo(int livro, int ex, int leitor, int diasAtras, {int? devolvidoApos, int renov = 0}) {
    final (exId, cod) = exemplaresPorLivro[livro][ex];
    final retirada = h.subtract(Duration(days: diasAtras));
    final ativo = devolvidoApos == null;
    b.set(db.collection('emprestimos').doc(), {
      'exemplarId': exId, 'exemplarCodigo': cod, 'livroId': livroIds[livro], 'livroTitulo': _livros[livro][0],
      'leitorId': leitorIds[leitor], 'retiradaEm': retirada,
      'prevista': retirada.add(Duration(days: 14 * (1 + renov))),
      'devolvidoEm': devolvidoApos == null ? null : retirada.add(Duration(days: devolvidoApos)),
      'renovacoes': renov, 'ativo': ativo, 'registradoPor': loja.emailUsuario,
    });
  }

  // Histórico (devolvidos) espalhado pelos últimos meses
  emprestimo(2, 0, 0, 200, devolvidoApos: 12);
  emprestimo(9, 0, 4, 170, devolvidoApos: 14);
  emprestimo(16, 0, 1, 150, devolvidoApos: 20, renov: 1);
  emprestimo(5, 0, 0, 120, devolvidoApos: 10);
  emprestimo(11, 0, 6, 100, devolvidoApos: 7);
  emprestimo(2, 1, 3, 90, devolvidoApos: 13);
  emprestimo(13, 0, 1, 75, devolvidoApos: 14);
  emprestimo(9, 1, 2, 60, devolvidoApos: 9);
  emprestimo(7, 0, 0, 45, devolvidoApos: 14);
  emprestimo(2, 0, 5, 35, devolvidoApos: 12);
  emprestimo(14, 0, 4, 28, devolvidoApos: 10);

  // Ativos: 2 atrasados, 1 vencendo, 2 no prazo
  final ativos = [(3, 0, 0, 20), (16, 0, 1, 25), (13, 0, 6, 12), (9, 0, 2, 5), (10, 0, 3, 2)];
  for (final (livro, ex, leitor, dias) in ativos) {
    emprestimo(livro, ex, leitor, dias);
    b.update(db.collection('exemplares').doc(exemplaresPorLivro[livro][ex].$1), {'status': 'emprestado'});
    b.update(db.collection('livros').doc(livroIds[livro]), {'disponiveis': (_livros[livro][6] as int) - 1});
  }

  // Fila de espera: Fernanda aguarda "Conhecendo Deus", que está com Maria.
  b.set(db.collection('reservas').doc(), {
    'livroId': livroIds[3], 'leitorId': leitorIds[4], 'status': 'aguardando', 'criadaEm': h.subtract(const Duration(days: 3)),
  });

  b.set(db.collection('config').doc('contadores'), {'proximoExemplar': codigo});
  await b.commit();
}

class TelaExemplos extends StatefulWidget {
  const TelaExemplos({super.key});

  @override
  State<TelaExemplos> createState() => _TelaExemplosState();
}

class _TelaExemplosState extends State<TelaExemplos> {
  bool carregando = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Dados de exemplo')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Carrega 20 livros, 8 leitores (2 crianças), empréstimos dos últimos meses, '
              '2 atrasados e uma pessoa na fila de espera — para você testar todas as telas.\n\n'
              'Depois de testar, exclua os livros e leitores de exemplo pelo próprio app '
              '(ou apague as coleções no Console do Firebase) antes de cadastrar o acervo real.'),
          const SizedBox(height: 24),
          BotaoGrande(Icons.download, carregando ? 'Carregando...' : 'Carregar dados de exemplo', carregando
              ? null
              : () async {
                  setState(() => carregando = true);
                  final ok = await executar(context, carregarExemplos, sucesso: 'Exemplos carregados!');
                  if (!mounted) return;
                  setState(() => carregando = false);
                  if (ok) Navigator.pop(context);
                }),
        ]),
      );
}
