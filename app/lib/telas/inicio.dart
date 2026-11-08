// Estrutura principal (barra inferior) e painel inicial.
import 'package:flutter/material.dart';

import '../componentes.dart';
import '../loja.dart';
import '../util.dart';
import 'acervo.dart';
import 'devolver.dart';
import 'emprestar.dart';
import 'leitores.dart';
import 'mais.dart';

class Inicio extends StatefulWidget {
  const Inicio({super.key});

  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  int aba = 0;
  int versaoEmprestar = 0;

  void irPara(int i) => setState(() {
        if (i == 1 && aba != 1) versaoEmprestar++; // recomeça o fluxo de empréstimo
        aba = i;
      });

  @override
  Widget build(BuildContext context) {
    return Ouvinte(builder: (context) {
      if (!loja.carregado) {
        return Scaffold(
          body: Center(
            child: loja.erro != null
                ? Vazio(Icons.cloud_off, loja.erro!)
                : const Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Carregando a biblioteca...'),
                  ]),
          ),
        );
      }
      final nAtrasados = loja.atrasados.length;
      return Scaffold(
        body: IndexedStack(index: aba, children: [
          Painel(irPara: irPara),
          TelaEmprestar(key: ValueKey(versaoEmprestar), aoConcluir: () => irPara(0)),
          const TelaDevolver(),
          const TelaAcervo(),
          const TelaMais(),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: aba,
          onDestinationSelected: irPara,
          destinations: [
            const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
            const NavigationDestination(icon: Icon(Icons.outbox_outlined), selectedIcon: Icon(Icons.outbox), label: 'Emprestar'),
            const NavigationDestination(
                icon: Icon(Icons.move_to_inbox_outlined), selectedIcon: Icon(Icons.move_to_inbox), label: 'Devolver'),
            const NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Acervo'),
            NavigationDestination(
              icon: Badge(isLabelVisible: nAtrasados > 0, label: Text('$nAtrasados'), child: const Icon(Icons.more_horiz)),
              label: 'Mais',
            ),
          ],
        ),
      );
    });
  }
}

class Painel extends StatelessWidget {
  final void Function(int) irPara;
  const Painel({super.key, required this.irPara});

  @override
  Widget build(BuildContext context) {
    final ativos = loja.emprestimosAtivos;
    final atrasados = loja.atrasados;
    final limiteSemana = hoje().add(const Duration(days: 7));
    final semana = ativos.where((e) => !loja.atrasado(e) && e.prevista != null && !e.prevista!.isAfter(limiteSemana)).length;

    // Mais lidos e leitores mais ativos (últimos 12 meses).
    final desde = hoje().subtract(const Duration(days: 365));
    final recentes = loja.emprestimos.values.where((e) => e.retiradaEm != null && e.retiradaEm!.isAfter(desde));
    final porLivro = <String, int>{};
    final porLeitor = <String, int>{};
    for (final e in recentes) {
      porLivro[e.livroId] = (porLivro[e.livroId] ?? 0) + 1;
      if (loja.leitores.containsKey(e.leitorId)) porLeitor[e.leitorId] = (porLeitor[e.leitorId] ?? 0) + 1;
    }
    final topLivros = (porLivro.entries.where((e) => loja.livros.containsKey(e.key)).toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .toList();
    final topLeitores = (porLeitor.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(5).toList();
    final destaques = loja.livrosOrdenados.where((l) => l.destaque).toList();

    return Scaffold(
      appBar: AppBar(title: Text(loja.config.nomeBiblioteca)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          _Numero('Emprestados', ativos.length, Icons.outbox, null, () => irPara(2)),
          const SizedBox(width: 8),
          _Numero('Atrasados', atrasados.length, Icons.schedule, atrasados.isEmpty ? null : corAlerta,
              () => abrir(context, (c) => const TelaAtrasados())),
          const SizedBox(width: 8),
          _Numero('Vencem na semana', semana, Icons.event, null, () => irPara(2)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: BotaoGrande(Icons.outbox, 'Emprestar', () => irPara(1))),
          const SizedBox(width: 12),
          Expanded(child: BotaoGrande(Icons.move_to_inbox, 'Devolver', () => irPara(2), contorno: true)),
        ]),
        if (loja.livros.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Bem-vindo! O acervo ainda está vazio.', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(loja.admin
                    ? 'Cadastre o primeiro livro na aba Acervo, ou carregue dados de exemplo em Mais > Dados de exemplo para testar.'
                    : 'Cadastre o primeiro livro na aba Acervo.'),
              ]),
            ),
          ),
        if (destaques.isNotEmpty) ...[
          const Secao('Sugestões do mês'),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: destaques.length,
              separatorBuilder: (c, i) => const SizedBox(width: 12),
              itemBuilder: (c, i) => InkWell(
                onTap: () => abrir(context, (c) => DetalheLivro(destaques[i].id)),
                child: SizedBox(
                  width: 80,
                  child: Column(children: [
                    Capa(destaques[i], largura: 80),
                    const SizedBox(height: 4),
                    Text(destaques[i].titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  ]),
                ),
              ),
            ),
          ),
        ],
        if (topLivros.isNotEmpty) ...[
          const Secao('Mais lidos (12 meses)'),
          Card(
            child: Column(children: [
              for (final e in topLivros)
                ListTile(
                  leading: Capa(loja.livros[e.key]!, largura: 32),
                  title: Text(loja.livros[e.key]!.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text('${e.value}×'),
                  onTap: () => abrir(context, (c) => DetalheLivro(e.key)),
                ),
            ]),
          ),
        ],
        if (topLeitores.isNotEmpty) ...[
          const Secao('Leitores mais ativos (12 meses)'),
          Card(
            child: Column(children: [
              for (final e in topLeitores)
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(loja.nomeLeitor(e.key)),
                  trailing: Text('${e.value} livro${e.value == 1 ? '' : 's'}'),
                  onTap: () => abrir(context, (c) => DetalheLeitor(e.key)),
                ),
            ]),
          ),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _Numero extends StatelessWidget {
  final String rotulo;
  final int valor;
  final IconData icone;
  final Color? cor;
  final VoidCallback onTap;
  const _Numero(this.rotulo, this.valor, this.icone, this.cor, this.onTap);

  @override
  Widget build(BuildContext context) {
    final c = cor ?? Theme.of(context).colorScheme.primary;
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        color: cor?.withValues(alpha: 0.08),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(children: [
              Icon(icone, color: c),
              const SizedBox(height: 4),
              Text('$valor', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: c)),
              Text(rotulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5)),
            ]),
          ),
        ),
      ),
    );
  }
}
