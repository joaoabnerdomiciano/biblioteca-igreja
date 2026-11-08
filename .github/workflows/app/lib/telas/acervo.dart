// Acervo: lista, detalhe e cadastro de livros e exemplares.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../componentes.dart';
import '../isbn.dart';
import '../loja.dart';
import '../modelos.dart';
import '../util.dart';
import 'devolver.dart';
import 'emprestar.dart';

class TelaAcervo extends StatefulWidget {
  const TelaAcervo({super.key});

  @override
  State<TelaAcervo> createState() => _TelaAcervoState();
}

class _TelaAcervoState extends State<TelaAcervo> {
  final busca = TextEditingController();
  String? categoria;
  bool soDisponiveis = false;

  @override
  Widget build(BuildContext context) {
    final lista = loja.livrosOrdenados
        .where((l) => categoria == null || l.categoria == categoria)
        .where((l) => !soDisponiveis || l.disponiveis > 0)
        .where((l) => corresponde(busca.text, [l.titulo, l.autor, l.editora, l.isbn, ...loja.exemplaresDoLivro(l.id).map((e) => e.codigo)]))
        .toList();
    final totalEx = loja.exemplares.values.where((e) => e.noAcervo).length;

    return Scaffold(
      appBar: AppBar(title: Text('Acervo (${loja.livros.length} títulos · $totalEx exemplares)')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => abrir(context, (c) => const FormLivro()),
        icon: const Icon(Icons.add),
        label: const Text('Novo livro'),
      ),
      body: Column(children: [
        CampoBusca(busca, 'Título, autor, ISBN ou código', () => setState(() {})),
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: const Text('Disponíveis'),
                selected: soDisponiveis,
                onSelected: (v) => setState(() => soDisponiveis = v),
              ),
            ),
            for (final c in categorias)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(c),
                  selected: categoria == c,
                  onSelected: (v) => setState(() => categoria = v ? c : null),
                ),
              ),
          ]),
        ),
        Expanded(
          child: lista.isEmpty
              ? Vazio(Icons.menu_book, loja.livros.isEmpty ? 'Nenhum livro cadastrado ainda.\nToque em "Novo livro".' : 'Nada encontrado.')
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: lista.length,
                  itemBuilder: (c, i) {
                    final l = lista[i];
                    return ListTile(
                      leading: Capa(l, largura: 40),
                      title: Text(l.titulo, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text([if (l.autor.isNotEmpty) l.autor, l.categoria].join(' · '),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: _disponibilidade(l),
                      onTap: () => abrir(context, (c) => DetalheLivro(l.id)),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

Widget _disponibilidade(Livro l) {
  if (l.total == 0) return const Etiqueta('Sem exemplar', Colors.grey);
  if (l.disponiveis == 0) return const Etiqueta('Emprestado', corAlerta);
  return Etiqueta(l.total == 1 ? 'Disponível' : '${l.disponiveis} de ${l.total}', corOk);
}

// =====================================================================
// Detalhe do livro
// =====================================================================
class DetalheLivro extends StatelessWidget {
  final String id;
  const DetalheLivro(this.id, {super.key});

  @override
  Widget build(BuildContext context) {
    final l = loja.livros[id];
    if (l == null) {
      return Scaffold(appBar: AppBar(), body: const Vazio(Icons.delete_outline, 'Este livro foi removido.'));
    }
    final exs = loja.exemplaresDoLivro(id);
    final fila = loja.filaDoLivro(id);
    final historico = loja.historicoDoLivro(id);
    final disponivel = exs.where((e) => e.status == 'disponivel').toList();
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Livro'),
        actions: [
          IconButton(
              tooltip: 'Editar', icon: const Icon(Icons.edit), onPressed: () => abrir(context, (c) => FormLivro(livro: l))),
          if (loja.admin)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'excluir' &&
                    await confirmar(context, 'Excluir livro?',
                        'O livro "${l.titulo}" e seus ${exs.length} exemplares serão excluídos. O histórico de empréstimos é mantido.',
                        ok: 'Excluir', perigo: true)) {
                  final ok = await executar(context, () => loja.excluirLivro(l), sucesso: 'Livro excluído.');
                  if (ok && context.mounted) Navigator.pop(context);
                }
              },
              itemBuilder: (c) => [const PopupMenuItem(value: 'excluir', child: Text('Excluir livro'))],
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Capa(l, largura: 96),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.titulo, style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              if (l.autor.isNotEmpty) Text(l.autor, style: t.bodyLarge),
              const SizedBox(height: 6),
              Text([if (l.editora.isNotEmpty) l.editora, if (l.ano != null) '${l.ano}'].join(' · ')),
              Text(l.categoria),
              if (l.estante.isNotEmpty) Text('Estante: ${l.estante}'),
              if (l.isbn.isNotEmpty) Text('ISBN: ${l.isbn}', style: t.bodySmall),
              const SizedBox(height: 8),
              _disponibilidade(l),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: BotaoGrande(
              Icons.outbox,
              'Emprestar',
              disponivel.isEmpty
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (c) => Ouvinte(builder: (c) => TelaEmprestar(exemplarInicial: disponivel.first)))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: BotaoGrande(Icons.people, 'Entrar na fila', () async {
              final leitor = await escolherLeitor(context, titulo: 'Quem vai entrar na fila?');
              if (leitor != null) {
                await executar(context, () => loja.reservar(id, leitor.id),
                    sucesso: '${primeiroNome(leitor.nome)} entrou na fila.');
              }
            }, contorno: true),
          ),
        ]),
        Card(
          margin: const EdgeInsets.only(top: 16),
          child: SwitchListTile(
            title: const Text('Sugestão de leitura do mês'),
            subtitle: Text(l.destaque
                ? (l.destaqueNota.isEmpty ? 'Aparece em destaque no catálogo' : '"${l.destaqueNota}"')
                : 'Destacar este livro no catálogo'),
            value: l.destaque,
            onChanged: (v) async {
              var nota = l.destaqueNota;
              if (v) {
                final r = await _pedirTexto(context, 'Recado sobre o livro (opcional)',
                    'Ex.: "Indicação do pastor para o mês da família"', nota);
                if (r == null) return;
                nota = r;
              }
              await executar(context, () => loja.definirDestaque(l, v, nota));
            },
          ),
        ),
        if (l.sinopse.isNotEmpty) ...[
          const Secao('Sinopse'),
          Text(l.sinopse),
        ],
        Secao('Exemplares (${exs.length})',
            acao: TextButton.icon(
                onPressed: () => dialogoNovosExemplares(context, id), icon: const Icon(Icons.add), label: const Text('Adicionar'))),
        for (final e in exs) _TileExemplar(e),
        if (fila.isNotEmpty) ...[
          Secao('Fila de espera (${fila.length})'),
          for (final (i, r) in fila.indexed)
            ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(loja.nomeLeitor(r.leitorId)),
              subtitle: Text(r.status == 'avisado'
                  ? 'Avisado em ${fmtData(r.avisadoEm)}'
                  : 'Na fila desde ${fmtData(r.criadaEm)}'),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'avisar') await avisarFila(context, r);
                  if (v == 'cancelar') await executar(context, () => loja.cancelarReserva(r), sucesso: 'Reserva cancelada.');
                },
                itemBuilder: (c) => const [
                  PopupMenuItem(value: 'avisar', child: Text('Avisar pelo WhatsApp')),
                  PopupMenuItem(value: 'cancelar', child: Text('Tirar da fila')),
                ],
              ),
            ),
        ],
        Secao('Histórico (${historico.length} empréstimo${historico.length == 1 ? '' : 's'})'),
        if (historico.isEmpty) const Text('Ainda não foi emprestado.'),
        for (final h in historico.take(15))
          ListTile(
            dense: true,
            title: Text(loja.nomeLeitor(h.leitorId)),
            subtitle: Text('${h.exemplarCodigo} · ${fmtData(h.retiradaEm)} → ${h.ativo ? 'com o leitor' : fmtData(h.devolvidoEm)}'),
          ),
        const SizedBox(height: 32),
      ]),
    );
  }
}

class _TileExemplar extends StatelessWidget {
  final Exemplar e;
  const _TileExemplar(this.e);

  @override
  Widget build(BuildContext context) {
    final emp = loja.emprestimoDoExemplar(e.id);
    final cor = switch (e.status) {
      'disponivel' => corOk,
      'emprestado' => corAlerta,
      'reparo' => corAtencao,
      _ => Colors.grey,
    };
    final opcoes = <String>[
      'disponivel',
      'reparo',
      if (e.origem == 'cedido') 'devolvido_dono',
      'baixado',
    ].where((s) => s != e.status).toList();

    return Card(
      child: ListTile(
        title: Text(e.codigo, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.origemTexto),
          if (emp != null) Text('Com ${loja.nomeLeitor(emp.leitorId)} até ${fmtData(emp.prevista)}'),
          const SizedBox(height: 4),
          Etiqueta(statusExemplar[e.status] ?? e.status, cor),
        ]),
        isThreeLine: true,
        onTap: emp != null ? () => acoesEmprestimo(context, emp) : null,
        trailing: e.status == 'emprestado'
            ? const Icon(Icons.chevron_right)
            : PopupMenuButton<String>(
                tooltip: 'Mudar situação',
                onSelected: (v) async {
                  if (v == 'excluir') {
                    if (await confirmar(context, 'Excluir exemplar?', 'O exemplar ${e.codigo} será excluído.',
                        ok: 'Excluir', perigo: true)) {
                      await executar(context, () => loja.excluirExemplar(e));
                    }
                    return;
                  }
                  await executar(context, () => loja.mudarStatusExemplar(e, v),
                      sucesso: '${e.codigo}: ${statusExemplar[v]}.');
                },
                itemBuilder: (c) => [
                  for (final s in opcoes) PopupMenuItem(value: s, child: Text('Marcar: ${statusExemplar[s]}')),
                  if (loja.admin) const PopupMenuItem(value: 'excluir', child: Text('Excluir exemplar')),
                ],
              ),
      ),
    );
  }
}

Future<String?> _pedirTexto(BuildContext context, String titulo, String dica, String inicial) {
  final c = TextEditingController(text: inicial);
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(titulo),
      content: TextField(controller: c, maxLines: 3, decoration: InputDecoration(hintText: dica)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('OK')),
      ],
    ),
  );
}

// =====================================================================
// Origem dos exemplares (comprado / doado / cedido)
// =====================================================================
class EscolhaOrigem {
  String origem = 'comprado';
  final nome = TextEditingController();
}

class CamposOrigem extends StatefulWidget {
  final EscolhaOrigem escolha;
  const CamposOrigem(this.escolha, {super.key});

  @override
  State<CamposOrigem> createState() => _CamposOrigemState();
}

class _CamposOrigemState extends State<CamposOrigem> {
  @override
  Widget build(BuildContext context) {
    final e = widget.escolha;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SegmentedButton<String>(
        segments: [for (final o in origens.entries) ButtonSegment(value: o.key, label: Text(o.value))],
        selected: {e.origem},
        onSelectionChanged: (s) => setState(() => e.origem = s.first),
      ),
      if (e.origem != 'comprado') ...[
        const SizedBox(height: 12),
        TextField(
          controller: e.nome,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: e.origem == 'doado' ? 'Nome de quem doou (opcional)' : 'Dono do livro',
            helperText: e.origem == 'cedido' ? 'O livro continua sendo dessa pessoa e pode ser devolvido a ela.' : null,
          ),
        ),
      ],
    ]);
  }
}

Future<void> dialogoNovosExemplares(BuildContext context, String livroId) async {
  final escolha = EscolhaOrigem();
  var qtd = 1;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(c).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Adicionar exemplares', style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 16),
          _Quantidade(qtd, (v) => setS(() => qtd = v)),
          const SizedBox(height: 16),
          CamposOrigem(escolha),
          const SizedBox(height: 16),
          BotaoGrande(Icons.add, 'Adicionar', () => Navigator.pop(c, true)),
        ]),
      ),
    ),
  );
  if (ok != true) return;
  if (escolha.origem == 'cedido' && escolha.nome.text.trim().isEmpty) {
    mostrarAviso(context, 'Informe quem é o dono do livro cedido.');
    return;
  }
  try {
    final cods = await loja.adicionarExemplares(livroId, qtd, escolha.origem, escolha.nome.text);
    mostrarAviso(context, 'Criado${cods.length == 1 ? '' : 's'}: ${cods.join(', ')}. Anote o código no livro.');
  } catch (e) {
    mostrarAviso(context, mensagemDeErro(e));
  }
}

class _Quantidade extends StatelessWidget {
  final int valor;
  final ValueChanged<int> aoMudar;
  const _Quantidade(this.valor, this.aoMudar);

  @override
  Widget build(BuildContext context) => Row(children: [
        const Expanded(child: Text('Quantidade de exemplares', style: TextStyle(fontSize: 16))),
        IconButton.outlined(onPressed: valor > 1 ? () => aoMudar(valor - 1) : null, icon: const Icon(Icons.remove)),
        SizedBox(width: 40, child: Text('$valor', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20))),
        IconButton.outlined(onPressed: valor < 20 ? () => aoMudar(valor + 1) : null, icon: const Icon(Icons.add)),
      ]);
}

// =====================================================================
// Cadastro / edição de livro
// =====================================================================
class FormLivro extends StatefulWidget {
  final Livro? livro;
  const FormLivro({super.key, this.livro});

  @override
  State<FormLivro> createState() => _FormLivroState();
}

class _FormLivroState extends State<FormLivro> {
  late final bool novo = widget.livro == null;
  late final Livro l = widget.livro == null
      ? Livro(id: loja.novoId('livros'))
      : (Livro(id: widget.livro!.id)
        ..titulo = widget.livro!.titulo
        ..autor = widget.livro!.autor
        ..editora = widget.livro!.editora
        ..isbn = widget.livro!.isbn
        ..categoria = widget.livro!.categoria
        ..estante = widget.livro!.estante
        ..sinopse = widget.livro!.sinopse
        ..capaUrl = widget.livro!.capaUrl
        ..ano = widget.livro!.ano
        ..temFoto = widget.livro!.temFoto
        ..destaque = widget.livro!.destaque
        ..destaqueNota = widget.livro!.destaqueNota);

  late final isbn = TextEditingController(text: l.isbn);
  late final titulo = TextEditingController(text: l.titulo);
  late final autor = TextEditingController(text: l.autor);
  late final editora = TextEditingController(text: l.editora);
  late final ano = TextEditingController(text: l.ano?.toString() ?? '');
  late final estante = TextEditingController(text: l.estante);
  late final sinopse = TextEditingController(text: l.sinopse);
  final origem = EscolhaOrigem();
  int qtd = 1;
  Uint8List? fotoNova;
  bool removerFoto = false, buscando = false, salvando = false;

  Future<void> _buscarIsbn() async {
    FocusScope.of(context).unfocus();
    setState(() => buscando = true);
    final d = await buscarIsbn(isbn.text);
    if (!mounted) return;
    setState(() => buscando = false);
    if (d == null) {
      mostrarAviso(context, 'Não encontrei esse ISBN. Preencha os dados à mão.');
      return;
    }
    setState(() {
      void preencher(TextEditingController c, String v) {
        if (c.text.trim().isEmpty && v.isNotEmpty) c.text = v;
      }

      preencher(titulo, d.titulo);
      preencher(autor, d.autor);
      preencher(editora, d.editora);
      preencher(sinopse, d.sinopse);
      if (d.ano != null) preencher(ano, '${d.ano}');
      if (l.capaUrl.isEmpty) l.capaUrl = d.capaUrl;
    });
    mostrarAviso(context, 'Dados encontrados! Confira antes de salvar.');
  }

  Future<void> _foto(ImageSource fonte) async {
    try {
      final x = await ImagePicker().pickImage(source: fonte, maxWidth: 480, maxHeight: 720, imageQuality: 60);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      setState(() {
        fotoNova = bytes;
        removerFoto = false;
      });
    } catch (e) {
      mostrarAviso(context, 'Não consegui abrir a câmera.');
    }
  }

  Future<void> _salvar() async {
    if (titulo.text.trim().isEmpty) {
      mostrarAviso(context, 'Informe o título.');
      return;
    }
    if (novo && origem.origem == 'cedido' && origem.nome.text.trim().isEmpty) {
      mostrarAviso(context, 'Informe quem é o dono do livro cedido.');
      return;
    }
    l
      ..isbn = limparIsbn(isbn.text)
      ..titulo = titulo.text
      ..autor = autor.text
      ..editora = editora.text
      ..ano = int.tryParse(ano.text.trim())
      ..estante = estante.text
      ..sinopse = sinopse.text;
    setState(() => salvando = true);
    final ok = await executar(context, () async {
      if (novo) {
        await loja.criarLivro(l, quantidade: qtd, origem: origem.origem, origemNome: origem.nome.text);
      } else {
        await loja.atualizarLivro(l);
      }
      if (fotoNova != null) await loja.salvarCapa(l.id, fotoNova!);
      if (removerFoto && l.temFoto) await loja.removerCapa(l.id);
    }, sucesso: novo ? 'Livro cadastrado!' : 'Alterações salvas.');
    if (!mounted) return;
    setState(() => salvando = false);
    if (ok) Navigator.pop(context);
  }

  Future<void> _escolherCategoria() async {
    final c = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (s) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final c in categorias)
            ListTile(
              title: Text(c),
              trailing: c == l.categoria ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(s, c),
            ),
        ]),
      ),
    );
    if (c != null) setState(() => l.categoria = c);
  }

  Widget _previaCapa() {
    if (fotoNova != null) {
      return ClipRRect(
          borderRadius: BorderRadius.circular(6), child: Image.memory(fotoNova!, width: 80, height: 116, fit: BoxFit.cover));
    }
    final temp = Livro(id: l.id, titulo: titulo.text, capaUrl: l.capaUrl, temFoto: l.temFoto && !removerFoto);
    return Capa(temp, largura: 80);
  }

  @override
  Widget build(BuildContext context) {
    const espaco = SizedBox(height: 14);
    return Scaffold(
      appBar: AppBar(title: Text(novo ? 'Novo livro' : 'Editar livro')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextField(
              controller: isbn,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ISBN', helperText: 'Número no verso, perto do código de barras'),
              onSubmitted: (_) => _buscarIsbn(),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              onPressed: buscando ? null : _buscarIsbn,
              icon: buscando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.travel_explore),
              label: const Text('Buscar'),
            ),
          ),
        ]),
        espaco,
        TextField(
            controller: titulo,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Título *'),
            onChanged: (_) => setState(() {})),
        espaco,
        TextField(controller: autor, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Autor')),
        espaco,
        Row(children: [
          Expanded(
              flex: 2,
              child: TextField(
                  controller: editora, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Editora'))),
          const SizedBox(width: 12),
          Expanded(
              child: TextField(controller: ano, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ano'))),
        ]),
        espaco,
        InkWell(
          onTap: _escolherCategoria,
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Categoria *', suffixIcon: Icon(Icons.arrow_drop_down)),
            child: Text(l.categoria),
          ),
        ),
        espaco,
        TextField(
            controller: estante,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Localização na estante', hintText: 'Ex.: A2, Prateleira 3')),
        espaco,
        TextField(controller: sinopse, maxLines: 4, decoration: const InputDecoration(labelText: 'Sinopse (opcional)')),
        const Secao('Capa'),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _previaCapa(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              OutlinedButton.icon(
                  onPressed: () => _foto(ImageSource.camera), icon: const Icon(Icons.photo_camera), label: const Text('Tirar foto')),
              OutlinedButton.icon(
                  onPressed: () => _foto(ImageSource.gallery), icon: const Icon(Icons.photo_library), label: const Text('Da galeria')),
              if (fotoNova != null || (l.temFoto && !removerFoto) || l.capaUrl.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() {
                    fotoNova = null;
                    removerFoto = true;
                    l.capaUrl = '';
                  }),
                  child: const Text('Remover capa'),
                ),
            ]),
          ),
        ]),
        if (novo) ...[
          const Secao('Exemplares'),
          _Quantidade(qtd, (v) => setState(() => qtd = v)),
          const SizedBox(height: 12),
          CamposOrigem(origem),
          const SizedBox(height: 8),
          const Text('Cada exemplar recebe um código (BIB-0001...). Anote-o na folha de rosto do livro.',
              style: TextStyle(fontSize: 13)),
        ],
        const SizedBox(height: 24),
        BotaoGrande(Icons.save, salvando ? 'Salvando...' : 'Salvar', salvando ? null : _salvar),
        const SizedBox(height: 24),
      ]),
    );
  }
}
