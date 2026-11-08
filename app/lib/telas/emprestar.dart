// Fluxo de empréstimo em 3 passos: leitor → livro → confirmar.
import 'package:flutter/material.dart';

import '../componentes.dart';
import '../loja.dart';
import '../modelos.dart';
import '../util.dart';
import 'leitores.dart';

class TelaEmprestar extends StatefulWidget {
  final Leitor? leitorInicial;
  final Exemplar? exemplarInicial;

  /// Chamado ao terminar. Se nulo, a tela é fechada (quando aberta por cima de outra).
  final VoidCallback? aoConcluir;
  const TelaEmprestar({super.key, this.leitorInicial, this.exemplarInicial, this.aoConcluir});

  @override
  State<TelaEmprestar> createState() => _TelaEmprestarState();
}

class _TelaEmprestarState extends State<TelaEmprestar> {
  Leitor? leitor;
  Exemplar? exemplar;
  bool salvando = false;
  final busca = TextEditingController();

  @override
  void initState() {
    super.initState();
    leitor = widget.leitorInicial;
    exemplar = widget.exemplarInicial;
  }

  int get passo => leitor == null ? 1 : (exemplar == null ? 2 : 3);

  void _voltar() => setState(() {
        busca.clear();
        if (passo == 3) {
          exemplar = null;
        } else {
          leitor = null;
        }
      });

  @override
  Widget build(BuildContext context) {
    // Se algo mudou enquanto a tela estava aberta (ex.: outro voluntário emprestou o livro).
    if (leitor != null && !loja.leitores.containsKey(leitor!.id)) leitor = null;
    if (exemplar != null) {
      final atual = loja.exemplares[exemplar!.id];
      if (atual == null || atual.status != 'disponivel') exemplar = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emprestar'),
        leading: passo > 1 && widget.aoConcluir != null ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _voltar) : null,
      ),
      body: Column(children: [
        _Passos(passo),
        Expanded(
          child: switch (passo) {
            1 => _passoLeitor(),
            2 => _passoLivro(),
            _ => _passoConfirmar(),
          },
        ),
      ]),
    );
  }

  // ---------------- Passo 1 ----------------
  Widget _passoLeitor() {
    final limite = loja.config.limite;
    final lista = loja.leitoresOrdenados.where((l) => corresponde(busca.text, [l.nome, l.grupo])).toList();
    return Column(children: [
      CampoBusca(busca, 'Quem vai levar o livro?', () => setState(() {})),
      Expanded(
        child: ListView(children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_add)),
            title: const Text('Cadastrar nova pessoa'),
            onTap: () async {
              final novo = await abrir<Leitor>(context, (c) => const FormLeitor());
              if (novo != null) setState(() => leitor = novo);
            },
          ),
          const Divider(height: 1),
          if (lista.isEmpty) const Vazio(Icons.person_search, 'Ninguém encontrado com esse nome.'),
          for (final l in lista) _tileLeitor(l, limite),
        ]),
      ),
    ]);
  }

  Widget _tileLeitor(Leitor l, int limite) {
    final n = loja.ativosDoLeitor(l.id).length;
    final cheio = n >= limite;
    final resp = l.menor ? loja.leitores[l.responsavelId] : null;
    final partes = [
      if (resp != null) 'Responsável: ${resp.nome}',
      if (l.grupo.isNotEmpty) l.grupo,
      if (cheio) 'Já está com $limite livros',
    ];
    return ListTile(
      enabled: !cheio,
      leading: CircleAvatar(child: Text(l.nome.isEmpty ? '?' : l.nome[0].toUpperCase())),
      title: Text(l.nome),
      subtitle: partes.isEmpty ? null : Text(partes.join(' · ')),
      trailing: Text('$n/$limite'),
      onTap: () => setState(() {
        leitor = l;
        busca.clear();
      }),
    );
  }

  // ---------------- Passo 2 ----------------
  Widget _passoLivro() {
    final disponiveis = loja.exemplaresDisponiveis.where((e) {
      final l = loja.livros[e.livroId]!;
      return corresponde(busca.text, [l.titulo, l.autor, e.codigo, l.categoria]);
    }).toList();
    // Livros que combinam com a busca mas estão todos emprestados.
    final indisponiveis = busca.text.trim().isEmpty
        ? <Livro>[]
        : loja.livrosOrdenados
            .where((l) => l.disponiveis == 0 && l.total > 0 && corresponde(busca.text, [l.titulo, l.autor]))
            .toList();

    return Column(children: [
      _cartaoLeitor(),
      CampoBusca(busca, 'Título, autor ou código (BIB-...)', () => setState(() {})),
      Expanded(
        child: ListView(children: [
          if (disponiveis.isEmpty && indisponiveis.isEmpty)
            const Vazio(Icons.menu_book, 'Nenhum livro disponível encontrado.'),
          for (final e in disponiveis)
            ListTile(
              leading: Capa(loja.livros[e.livroId]!, largura: 36),
              title: Text(loja.livros[e.livroId]!.titulo),
              subtitle: Text([
                if (loja.livros[e.livroId]!.autor.isNotEmpty) loja.livros[e.livroId]!.autor,
                e.codigo,
                if (loja.livros[e.livroId]!.estante.isNotEmpty) 'Estante ${loja.livros[e.livroId]!.estante}',
              ].join(' · ')),
              onTap: () => setState(() => exemplar = e),
            ),
          if (indisponiveis.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Emprestados no momento', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final l in indisponiveis)
              ListTile(
                leading: Capa(l, largura: 36),
                title: Text(l.titulo),
                subtitle: Text('${loja.filaDoLivro(l.id).length} na fila'),
                trailing: TextButton(
                  onPressed: () => executar(context, () => loja.reservar(l.id, leitor!.id),
                      sucesso: '${primeiroNome(leitor!.nome)} entrou na fila de "${l.titulo}".'),
                  child: const Text('Entrar na fila'),
                ),
              ),
          ],
        ]),
      ),
    ]);
  }

  Widget _cartaoLeitor() => Card(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: ListTile(
          leading: const Icon(Icons.person),
          title: Text(leitor!.nome),
          subtitle: Text('Está com ${loja.ativosDoLeitor(leitor!.id).length} de ${loja.config.limite} livros'),
          trailing: TextButton(
              onPressed: () => setState(() {
                    leitor = null;
                    exemplar = null;
                  }),
              child: const Text('Trocar')),
        ),
      );

  // ---------------- Passo 3 ----------------
  Widget _passoConfirmar() {
    final l = loja.livros[exemplar!.livroId]!;
    final prevista = hoje().add(Duration(days: loja.config.prazoDias));
    final fila = loja.filaDoLivro(l.id);
    final naFrente = fila.takeWhile((r) => r.leitorId != leitor!.id).toList();

    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Capa(l, largura: 72),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.titulo, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                if (l.autor.isNotEmpty) Text(l.autor),
                const SizedBox(height: 6),
                Text('Exemplar ${exemplar!.codigo}'),
              ]),
            ),
          ]),
        ),
      ),
      Card(
        child: Column(children: [
          ListTile(leading: const Icon(Icons.person), title: Text(leitor!.nome), subtitle: const Text('Quem leva')),
          ListTile(
            leading: const Icon(Icons.event),
            title: Text(fmtData(prevista)),
            subtitle: Text('Devolver até (${loja.config.prazoDias} dias)'),
          ),
        ]),
      ),
      if (naFrente.isNotEmpty)
        Card(
          color: corAtencao.withValues(alpha: 0.1),
          child: ListTile(
            leading: const Icon(Icons.people, color: corAtencao),
            title: Text('${naFrente.length} pessoa${naFrente.length == 1 ? '' : 's'} na fila antes'),
            subtitle: Text('${loja.nomeLeitor(naFrente.first.leitorId)} está esperando este livro. '
                'Você pode emprestar mesmo assim.'),
          ),
        ),
      const SizedBox(height: 16),
      BotaoGrande(Icons.check, salvando ? 'Registrando...' : 'Confirmar empréstimo', salvando ? null : _confirmar),
      const SizedBox(height: 8),
      TextButton(onPressed: _voltar, child: const Text('Voltar')),
    ]);
  }

  Future<void> _confirmar() async {
    setState(() => salvando = true);
    try {
      final emp = await loja.emprestar(leitor!, exemplar!);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: corOk, size: 48),
          title: const Text('Empréstimo registrado!'),
          content: Text('"${emp.livroTitulo}" com ${primeiroNome(leitor!.nome)}.\n'
              'Devolver até ${fmtData(emp.prevista)}.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );
      if (!mounted) return;
      if (widget.aoConcluir != null) {
        widget.aoConcluir!();
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) mostrarAviso(context, mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }
}

class _Passos extends StatelessWidget {
  final int atual;
  const _Passos(this.atual);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget bolinha(int n, String texto) {
      final feito = n < atual, ativo = n == atual;
      return Expanded(
        child: Column(children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: ativo || feito ? cs.primary : cs.surfaceContainerHighest,
            child: feito
                ? Icon(Icons.check, size: 16, color: cs.onPrimary)
                : Text('$n', style: TextStyle(color: ativo ? cs.onPrimary : cs.onSurfaceVariant, fontSize: 13)),
          ),
          const SizedBox(height: 4),
          Text(texto, style: TextStyle(fontSize: 12, fontWeight: ativo ? FontWeight.bold : FontWeight.normal)),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [bolinha(1, 'Leitor'), bolinha(2, 'Livro'), bolinha(3, 'Confirmar')]),
    );
  }
}
