// Devoluções, renovações e aviso para quem está na fila.
import 'package:flutter/material.dart';

import '../componentes.dart';
import '../loja.dart';
import '../modelos.dart';
import '../util.dart';

class TelaDevolver extends StatefulWidget {
  const TelaDevolver({super.key});

  @override
  State<TelaDevolver> createState() => _TelaDevolverState();
}

class _TelaDevolverState extends State<TelaDevolver> {
  final busca = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final lista = loja.emprestimosAtivos
        .where((e) => corresponde(busca.text, [e.exemplarCodigo, loja.tituloLivro(e.livroId, e.livroTitulo), loja.nomeLeitor(e.leitorId)]))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Devolver')),
      body: Column(children: [
        CampoBusca(busca, 'Código, livro ou nome do leitor', () => setState(() {})),
        Expanded(
          child: lista.isEmpty
              ? Vazio(Icons.inbox, busca.text.isEmpty ? 'Nenhum livro emprestado no momento.' : 'Nada encontrado.')
              : ListView.builder(
                  itemCount: lista.length,
                  itemBuilder: (c, i) => CartaoEmprestimo(lista[i], onTap: () => acoesEmprestimo(context, lista[i])),
                ),
        ),
      ]),
    );
  }
}

class CartaoEmprestimo extends StatelessWidget {
  final Emprestimo e;
  final VoidCallback onTap;
  final Widget? extra;
  const CartaoEmprestimo(this.e, {super.key, required this.onTap, this.extra});

  @override
  Widget build(BuildContext context) {
    final livro = loja.livros[e.livroId];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            if (livro != null) Capa(livro, largura: 40) else const Icon(Icons.book, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(loja.tituloLivro(e.livroId, e.livroTitulo),
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${loja.nomeLeitor(e.leitorId)} · ${e.exemplarCodigo}'),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  etiquetaPrazo(e),
                  if (e.renovacoes > 0) Etiqueta('Renovado', Theme.of(context).colorScheme.primary),
                  if (e.lembreteEm != null) Etiqueta('Lembrado em ${fmtDataCurta(e.lembreteEm)}', Colors.blueGrey),
                ]),
                if (extra != null) extra!,
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Menu de ações de um empréstimo: devolver, renovar, lembrar.
Future<void> acoesEmprestimo(BuildContext context, Emprestimo e) async {
  final leitor = loja.leitores[e.leitorId];
  final titulo = loja.tituloLivro(e.livroId, e.livroTitulo);
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(titulo, style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text('${loja.nomeLeitor(e.leitorId)} · ${e.exemplarCodigo}'),
          Text('Retirado em ${fmtData(e.retiradaEm)} · devolver até ${fmtData(e.prevista)}'),
          const SizedBox(height: 16),
          BotaoGrande(Icons.move_to_inbox, 'Receber devolução', () async {
            Navigator.pop(c);
            await registrarDevolucao(context, e);
          }),
          const SizedBox(height: 8),
          BotaoGrande(
            Icons.update,
            loja.podeRenovar(e) ? 'Renovar por mais ${loja.config.prazoDias} dias' : 'Renovação já usada',
            loja.podeRenovar(e)
                ? () async {
                    Navigator.pop(c);
                    await _renovar(context, e);
                  }
                : null,
            contorno: true,
          ),
          if (leitor != null) ...[
            const SizedBox(height: 8),
            BotaoGrande(Icons.chat, 'Lembrete pelo WhatsApp', () async {
              Navigator.pop(c);
              await enviarLembrete(context, e);
            }, contorno: true),
          ],
        ]),
      ),
    ),
  );
}

Future<void> _renovar(BuildContext context, Emprestimo e) async {
  final fila = loja.filaDoLivro(e.livroId).where((r) => r.leitorId != e.leitorId).length;
  if (fila > 0 &&
      !await confirmar(context, 'Há gente esperando',
          '$fila pessoa${fila == 1 ? '' : 's'} na fila deste livro. Renovar mesmo assim?',
          ok: 'Renovar')) {
    return;
  }
  try {
    final nova = await loja.renovar(e);
    mostrarAviso(context, 'Renovado! Nova data: ${fmtData(nova)}.');
  } catch (err) {
    mostrarAviso(context, mensagemDeErro(err));
  }
}

Future<void> enviarLembrete(BuildContext context, Emprestimo e) async {
  final leitor = loja.leitores[e.leitorId];
  if (leitor == null) return;
  final m = loja.mensagem(loja.config.msgAtraso, leitor, loja.tituloLivro(e.livroId, e.livroTitulo), data: e.prevista);
  await abrirWhatsApp(context, m.telefone, m.texto);
  try {
    await loja.marcarLembrete(e);
  } catch (_) {}
}

Future<void> registrarDevolucao(BuildContext context, Emprestimo e) async {
  final ok = await executar(context, () => loja.devolver(e), sucesso: 'Devolução registrada. Obrigado!');
  if (!ok) return;
  // Alguém está esperando este livro?
  final fila = loja.filaDoLivro(e.livroId).where((r) => r.status == 'aguardando').toList();
  if (fila.isEmpty) return;
  final r = fila.first;
  final leitor = loja.leitores[r.leitorId];
  if (leitor == null) return;
  final avisar = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.notifications_active, size: 40),
      title: const Text('Tem alguém esperando!'),
      content: Text('${leitor.nome} está na fila de "${loja.tituloLivro(e.livroId, e.livroTitulo)}". '
          'Guarde o livro separado e avise a pessoa.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Depois')),
        FilledButton.icon(
            onPressed: () => Navigator.pop(c, true), icon: const Icon(Icons.chat), label: const Text('Avisar no WhatsApp')),
      ],
    ),
  );
  if (avisar == true) await avisarFila(context, r);
}

Future<void> avisarFila(BuildContext context, Reserva r) async {
  final leitor = loja.leitores[r.leitorId];
  if (leitor == null) return;
  final m = loja.mensagem(loja.config.msgFila, leitor, loja.tituloLivro(r.livroId));
  await abrirWhatsApp(context, m.telefone, m.texto);
  try {
    await loja.marcarAvisado(r);
  } catch (_) {}
}
