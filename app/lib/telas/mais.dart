// Menu "Mais": atrasados, reservas, leitores, relatórios, configurações e voluntários.
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../componentes.dart';
import '../exemplos.dart';
import '../loja.dart';
import '../modelos.dart';
import '../util.dart';
import 'acervo.dart';
import 'devolver.dart';
import 'leitores.dart';

class TelaMais extends StatelessWidget {
  const TelaMais({super.key});

  @override
  Widget build(BuildContext context) {
    final nAtrasados = loja.atrasados.length;
    final nReservas = loja.reservasAtivas.length;
    Widget item(IconData i, String t, Widget Function() tela, {String? sub, int badge = 0}) => ListTile(
          leading: Badge(isLabelVisible: badge > 0, label: Text('$badge'), child: Icon(i)),
          title: Text(t),
          subtitle: sub == null ? null : Text(sub),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => abrir(context, (c) => tela()),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      body: ListView(children: [
        item(Icons.schedule, 'Atrasados', () => const TelaAtrasados(),
            sub: nAtrasados == 0 ? 'Nenhum atraso 🎉' : '$nAtrasados empréstimo(s)', badge: nAtrasados),
        item(Icons.people_alt_outlined, 'Fila de espera', () => const TelaReservas(), sub: '$nReservas reserva(s) ativa(s)'),
        item(Icons.badge_outlined, 'Leitores', () => const TelaLeitores(), sub: '${loja.leitores.length} cadastrados'),
        item(Icons.bar_chart, 'Relatórios e exportação', () => const TelaRelatorios()),
        const Divider(),
        item(Icons.tune, 'Configurações', () => const TelaConfig(), sub: 'Prazo, limite e mensagens'),
        if (loja.admin) ...[
          item(Icons.admin_panel_settings_outlined, 'Voluntários', () => const TelaVoluntarios(),
              sub: 'Quem pode usar o app'),
          if (loja.livros.isEmpty)
            item(Icons.science_outlined, 'Dados de exemplo', () => const TelaExemplos(), sub: 'Para testar o app'),
        ],
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sair'),
          subtitle: Text(loja.emailUsuario + (loja.admin ? ' (administrador)' : '')),
          onTap: () async {
            if (await confirmar(context, 'Sair?', 'Você vai precisar entrar de novo com e-mail e senha.', ok: 'Sair')) {
              await FirebaseAuth.instance.signOut();
            }
          },
        ),
      ]),
    );
  }
}

// =====================================================================
class TelaAtrasados extends StatelessWidget {
  const TelaAtrasados({super.key});

  @override
  Widget build(BuildContext context) {
    final lista = loja.atrasados;
    return Scaffold(
      appBar: AppBar(title: Text('Atrasados (${lista.length})')),
      body: lista.isEmpty
          ? const Center(child: Vazio(Icons.celebration, 'Nenhum livro atrasado. Que bênção!'))
          : ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('Toque em "Lembrar" para abrir o WhatsApp com uma mensagem gentil já escrita.'),
              ),
              for (final e in lista)
                CartaoEmprestimo(
                  e,
                  onTap: () => acoesEmprestimo(context, e),
                  extra: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => enviarLembrete(context, e),
                      icon: const Icon(Icons.chat),
                      label: const Text('Lembrar'),
                    ),
                  ),
                ),
            ]),
    );
  }
}

// =====================================================================
class TelaReservas extends StatelessWidget {
  const TelaReservas({super.key});

  @override
  Widget build(BuildContext context) {
    final lista = loja.reservasAtivas;
    final porLivro = <String, List<Reserva>>{};
    for (final r in lista) {
      porLivro.putIfAbsent(r.livroId, () => []).add(r);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Fila de espera')),
      body: lista.isEmpty
          ? const Center(child: Vazio(Icons.people_outline, 'Ninguém na fila no momento.'))
          : ListView(padding: const EdgeInsets.all(8), children: [
              for (final entrada in porLivro.entries) _cartaoFila(context, entrada.key, entrada.value),
            ]),
    );
  }

  Widget _cartaoFila(BuildContext context, String livroId, List<Reserva> fila) {
    final livro = loja.livros[livroId];
    final disponivel = (livro?.disponiveis ?? 0) > 0;
    return Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ListTile(
          leading: livro == null ? const Icon(Icons.book) : Capa(livro, largura: 36),
          title: Text(loja.tituloLivro(livroId), style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: disponivel
              ? const Text('Disponível agora — avise o primeiro da fila!', style: TextStyle(color: corOk))
              : const Text('Ainda emprestado'),
          onTap: () => abrir(context, (c) => DetalheLivro(livroId)),
        ),
        for (final (i, r) in fila.indexed)
          ListTile(
            dense: true,
            leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
            title: Text(loja.nomeLeitor(r.leitorId)),
            subtitle: Text(r.status == 'avisado' ? 'Avisado em ${fmtData(r.avisadoEm)}' : 'Desde ${fmtData(r.criadaEm)}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.chat), tooltip: 'Avisar', onPressed: () => avisarFila(context, r)),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Tirar da fila',
                onPressed: () async {
                  if (await confirmar(context, 'Tirar da fila?', '${loja.nomeLeitor(r.leitorId)} sairá da fila.', ok: 'Tirar')) {
                    await executar(context, () => loja.cancelarReserva(r));
                  }
                },
              ),
            ]),
          ),
      ]),
    );
  }
}

// =====================================================================
class TelaRelatorios extends StatelessWidget {
  const TelaRelatorios({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final agora = hoje();
    // Empréstimos por mês (últimos 12 meses).
    final meses = List.generate(12, (i) => DateTime(agora.year, agora.month - 11 + i));
    final porMes = {for (final m in meses) '${m.year}-${m.month}': 0};
    final porCategoria = <String, int>{};
    for (final e in loja.emprestimos.values) {
      final d = e.retiradaEm;
      if (d == null) continue;
      final k = '${d.year}-${d.month}';
      if (porMes.containsKey(k)) porMes[k] = porMes[k]! + 1;
      final cat = loja.livros[e.livroId]?.categoria ?? 'Outros';
      porCategoria[cat] = (porCategoria[cat] ?? 0) + 1;
    }
    final maxMes = porMes.values.fold(0, (a, b) => a > b ? a : b);
    final cats = porCategoria.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxCat = cats.isEmpty ? 0 : cats.first.value;
    final emprestados = loja.emprestimos.values.map((e) => e.livroId).toSet();
    final nunca = loja.livrosOrdenados.where((l) => !emprestados.contains(l.id) && l.total > 0).toList();

    Widget barra(String rotulo, int valor, int max) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(width: 110, child: Text(rotulo, overflow: TextOverflow.ellipsis)),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: max == 0 ? 0 : valor / max,
                  child: Container(
                      height: 18, decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(4))),
                ),
              ),
            ),
            SizedBox(width: 36, child: Text('$valor', textAlign: TextAlign.right)),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Resumo('Títulos', loja.livros.length),
          _Resumo('Exemplares', loja.exemplares.values.where((e) => e.noAcervo).length),
          _Resumo('Leitores', loja.leitores.length),
          _Resumo('Empréstimos', loja.emprestimos.length),
        ]),
        const Secao('Empréstimos por mês'),
        for (final m in meses) barra('${nomesMeses[m.month - 1]}/${m.year % 100}', porMes['${m.year}-${m.month}']!, maxMes),
        const Secao('Categorias mais procuradas'),
        if (cats.isEmpty) const Text('Ainda sem empréstimos.'),
        for (final c in cats) barra(c.key, c.value, maxCat),
        Secao('Nunca emprestados (${nunca.length})'),
        if (nunca.isEmpty) const Text('Todos os livros já saíram pelo menos uma vez!'),
        for (final l in nunca.take(50))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Capa(l, largura: 28),
            title: Text(l.titulo),
            subtitle: Text(l.categoria),
            onTap: () => abrir(context, (c) => DetalheLivro(l.id)),
          ),
        const Secao('Exportar para planilha'),
        const Text('Gera um arquivo CSV, que abre no Excel ou no Google Planilhas.'),
        const SizedBox(height: 12),
        BotaoGrande(Icons.table_view, 'Exportar acervo', () => _exportarAcervo(context), contorno: true),
        const SizedBox(height: 8),
        BotaoGrande(Icons.table_view, 'Exportar empréstimos', () => _exportarEmprestimos(context), contorno: true),
        const SizedBox(height: 32),
      ]),
    );
  }

  Future<void> _compartilharCsv(BuildContext context, String nome, List<List<String>> linhas) async {
    String esc(String v) => '"${v.replaceAll('"', '""')}"';
    final csv = '﻿${linhas.map((l) => l.map(esc).join(';')).join('\r\n')}';
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/$nome');
      await f.writeAsString(csv);
      await Share.shareXFiles([XFile(f.path, mimeType: 'text/csv')], subject: nome);
    } catch (e) {
      mostrarAviso(context, 'Não consegui gerar o arquivo: $e');
    }
  }

  Future<void> _exportarAcervo(BuildContext context) {
    final linhas = <List<String>>[
      ['Código', 'Título', 'Autor', 'Editora', 'Ano', 'ISBN', 'Categoria', 'Estante', 'Origem', 'Situação'],
    ];
    final exs = loja.exemplares.values.where((e) => loja.livros.containsKey(e.livroId)).toList()
      ..sort((a, b) => a.codigo.compareTo(b.codigo));
    for (final e in exs) {
      final l = loja.livros[e.livroId]!;
      linhas.add([
        e.codigo, l.titulo, l.autor, l.editora, l.ano?.toString() ?? '', l.isbn, l.categoria, l.estante,
        e.origemTexto, statusExemplar[e.status] ?? e.status,
      ]);
    }
    return _compartilharCsv(context, 'acervo_${fmtData(hoje()).replaceAll('/', '-')}.csv', linhas);
  }

  Future<void> _exportarEmprestimos(BuildContext context) {
    final linhas = <List<String>>[
      ['Retirada', 'Previsto', 'Devolução', 'Código', 'Livro', 'Leitor', 'Renovações', 'Situação'],
    ];
    final lista = loja.emprestimos.values.toList()
      ..sort((a, b) => (b.retiradaEm ?? DateTime(0)).compareTo(a.retiradaEm ?? DateTime(0)));
    for (final e in lista) {
      linhas.add([
        fmtData(e.retiradaEm), fmtData(e.prevista), e.ativo ? '' : fmtData(e.devolvidoEm), e.exemplarCodigo,
        loja.tituloLivro(e.livroId, e.livroTitulo), loja.nomeLeitor(e.leitorId), '${e.renovacoes}',
        e.ativo ? (loja.atrasado(e) ? 'Atrasado' : 'Com o leitor') : 'Devolvido',
      ]);
    }
    return _compartilharCsv(context, 'emprestimos_${fmtData(hoje()).replaceAll('/', '-')}.csv', linhas);
  }
}

class _Resumo extends StatelessWidget {
  final String rotulo;
  final int valor;
  const _Resumo(this.rotulo, this.valor);

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Text('$valor', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text(rotulo),
            ]),
          ),
        ),
      );
}

// =====================================================================
class TelaConfig extends StatefulWidget {
  const TelaConfig({super.key});

  @override
  State<TelaConfig> createState() => _TelaConfigState();
}

class _TelaConfigState extends State<TelaConfig> {
  late final c = Config.fromMap(loja.config.toMap());
  late final nome = TextEditingController(text: c.nomeBiblioteca);
  late final msgAtraso = TextEditingController(text: c.msgAtraso);
  late final msgFila = TextEditingController(text: c.msgFila);

  Widget _numero(String rotulo, int valor, int min, int max, ValueChanged<int> f) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(rotulo),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(onPressed: loja.admin && valor > min ? () => setState(() => f(valor - 1)) : null, icon: const Icon(Icons.remove)),
          SizedBox(width: 32, child: Text('$valor', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18))),
          IconButton(onPressed: loja.admin && valor < max ? () => setState(() => f(valor + 1)) : null, icon: const Icon(Icons.add)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final admin = loja.admin;
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (!admin)
          const Card(
            child: ListTile(leading: Icon(Icons.lock_outline), title: Text('Somente o administrador pode alterar as configurações.')),
          ),
        TextField(controller: nome, enabled: admin, decoration: const InputDecoration(labelText: 'Nome da biblioteca')),
        const SizedBox(height: 8),
        _numero('Prazo de empréstimo (dias)', c.prazoDias, 1, 90, (v) => c.prazoDias = v),
        _numero('Renovações permitidas', c.renovacoes, 0, 5, (v) => c.renovacoes = v),
        _numero('Livros por pessoa ao mesmo tempo', c.limite, 1, 10, (v) => c.limite = v),
        const Secao('Mensagens do WhatsApp'),
        const Text('Use {nome} para o primeiro nome, {livro} para o título e {data} para a data prevista.',
            style: TextStyle(fontSize: 13)),
        const SizedBox(height: 12),
        TextField(controller: msgAtraso, enabled: admin, maxLines: 5, decoration: const InputDecoration(labelText: 'Lembrete de atraso')),
        const SizedBox(height: 12),
        TextField(controller: msgFila, enabled: admin, maxLines: 4, decoration: const InputDecoration(labelText: 'Aviso para quem está na fila')),
        if (admin) ...[
          TextButton(
            onPressed: () => setState(() {
              msgAtraso.text = Config.msgAtrasoPadrao;
              msgFila.text = Config.msgFilaPadrao;
            }),
            child: const Text('Restaurar mensagens padrão'),
          ),
          const SizedBox(height: 16),
          BotaoGrande(Icons.save, 'Salvar', () async {
            c
              ..nomeBiblioteca = nome.text.trim().isEmpty ? 'Biblioteca da Igreja' : nome.text.trim()
              ..msgAtraso = msgAtraso.text
              ..msgFila = msgFila.text;
            final ok = await executar(context, () => loja.salvarConfig(c), sucesso: 'Configurações salvas.');
            if (ok && context.mounted) Navigator.pop(context);
          }),
        ],
        const SizedBox(height: 32),
      ]),
    );
  }
}

// =====================================================================
class TelaVoluntarios extends StatelessWidget {
  const TelaVoluntarios({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Voluntários')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: const Text('Liberar e-mail'),
        onPressed: () async {
          final ctrl = TextEditingController();
          final email = await showDialog<String>(
            context: context,
            builder: (d) => AlertDialog(
              title: const Text('Liberar voluntário'),
              content: TextField(
                controller: ctrl,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'E-mail do voluntário'),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
                FilledButton(onPressed: () => Navigator.pop(d, ctrl.text), child: const Text('Liberar')),
              ],
            ),
          );
          if (email != null && email.trim().isNotEmpty) {
            await executar(context, () => loja.adicionarVoluntario(email),
                sucesso: 'Liberado! A pessoa já pode criar a conta no app com esse e-mail.');
          }
        },
      ),
      body: ListView(children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Só os e-mails desta lista conseguem usar o app. A pessoa instala o app, '
              'toca em "Criar conta" com o mesmo e-mail e confirma pelo link recebido.'),
        ),
        ListTile(
          leading: const Icon(Icons.verified_user),
          title: Text(loja.emailUsuario),
          subtitle: const Text('Administrador'),
        ),
        for (final e in loja.voluntarios)
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(e),
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: 'Remover acesso',
              onPressed: () async {
                if (await confirmar(context, 'Remover acesso?', '$e não conseguirá mais usar o app.', ok: 'Remover', perigo: true)) {
                  await executar(context, () => loja.removerVoluntario(e));
                }
              },
            ),
          ),
      ]),
    );
  }
}
