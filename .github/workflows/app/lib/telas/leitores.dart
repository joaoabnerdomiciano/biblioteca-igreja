// Leitores: lista, detalhe com histórico e cadastro.
import 'package:flutter/material.dart';

import '../componentes.dart';
import '../loja.dart';
import '../modelos.dart';
import '../util.dart';
import 'acervo.dart';
import 'devolver.dart';
import 'emprestar.dart';

class TelaLeitores extends StatefulWidget {
  const TelaLeitores({super.key});

  @override
  State<TelaLeitores> createState() => _TelaLeitoresState();
}

class _TelaLeitoresState extends State<TelaLeitores> {
  final busca = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final lista = loja.leitoresOrdenados.where((l) => corresponde(busca.text, [l.nome, l.grupo, l.telefone])).toList();
    return Scaffold(
      appBar: AppBar(title: Text('Leitores (${loja.leitores.length})')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => abrir(context, (c) => const FormLeitor()),
        icon: const Icon(Icons.person_add),
        label: const Text('Novo leitor'),
      ),
      body: Column(children: [
        CampoBusca(busca, 'Buscar pelo nome ou grupo', () => setState(() {})),
        Expanded(
          child: lista.isEmpty
              ? const Vazio(Icons.people_outline, 'Nenhum leitor encontrado.')
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: lista.length,
                  itemBuilder: (c, i) {
                    final l = lista[i];
                    final n = loja.ativosDoLeitor(l.id).length;
                    final resp = l.menor ? loja.leitores[l.responsavelId] : null;
                    return ListTile(
                      leading: CircleAvatar(child: Text(l.nome.isEmpty ? '?' : l.nome[0].toUpperCase())),
                      title: Text(l.nome),
                      subtitle: Text([
                        if (resp != null) 'Criança · resp. ${primeiroNome(resp.nome)}',
                        if (l.grupo.isNotEmpty) l.grupo,
                      ].join(' · ')),
                      trailing: n > 0 ? Etiqueta('$n livro${n == 1 ? '' : 's'}', Theme.of(context).colorScheme.primary) : null,
                      onTap: () => abrir(context, (c) => DetalheLeitor(l.id)),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class DetalheLeitor extends StatelessWidget {
  final String id;
  const DetalheLeitor(this.id, {super.key});

  @override
  Widget build(BuildContext context) {
    final l = loja.leitores[id];
    if (l == null) return Scaffold(appBar: AppBar(), body: const Vazio(Icons.person_off, 'Cadastro removido.'));
    final ativos = loja.ativosDoLeitor(id);
    final historico = loja.historicoDoLeitor(id).where((e) => !e.ativo).toList();
    final reservas = loja.reservasDoLeitor(id);
    final deps = loja.dependentes(id);
    final resp = l.menor ? loja.leitores[l.responsavelId] : null;
    final contato = loja.contato(l);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leitor'),
        actions: [
          IconButton(icon: const Icon(Icons.edit), tooltip: 'Editar', onPressed: () => abrir(context, (c) => FormLeitor(leitor: l))),
          if (loja.admin)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (await confirmar(
                    context,
                    'Excluir cadastro?',
                    'Os dados pessoais de ${l.nome} serão apagados (LGPD). '
                        'Os empréstimos antigos continuam nas estatísticas como "Leitor removido".',
                    ok: 'Excluir',
                    perigo: true)) {
                  final ok = await executar(context, () => loja.excluirLeitor(l), sucesso: 'Cadastro excluído.');
                  if (ok && context.mounted) Navigator.pop(context);
                }
              },
              itemBuilder: (c) => const [PopupMenuItem(value: 'excluir', child: Text('Excluir cadastro'))],
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(l.nome, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        if (l.grupo.isNotEmpty) Text(l.grupo),
        const SizedBox(height: 8),
        if (resp != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.family_restroom),
            title: Text('Responsável: ${resp.nome}'),
            onTap: () => abrir(context, (c) => DetalheLeitor(resp.id)),
          ),
        if (contato.telefone.isNotEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.phone),
            title: Text(contato.telefone),
            subtitle: l.menor && l.telefone.isEmpty ? const Text('Telefone do responsável') : null,
            trailing: IconButton(
              icon: const Icon(Icons.chat),
              tooltip: 'Abrir WhatsApp',
              onPressed: () => abrirWhatsApp(context, contato.telefone, 'Olá, ${primeiroNome(contato.nome)}! '),
            ),
          ),
        if (l.email.isNotEmpty)
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.email_outlined), title: Text(l.email)),
        if (l.obs.isNotEmpty)
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.notes), title: Text(l.obs)),
        const SizedBox(height: 8),
        BotaoGrande(
          Icons.outbox,
          ativos.length >= loja.config.limite ? 'Já está com ${loja.config.limite} livros' : 'Emprestar para ${primeiroNome(l.nome)}',
          ativos.length >= loja.config.limite
              ? null
              : () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (c) => Ouvinte(builder: (c) => TelaEmprestar(leitorInicial: l)))),
        ),
        Secao('Com ${l.menor ? 'a criança' : 'a pessoa'} agora (${ativos.length})'),
        if (ativos.isEmpty) const Text('Nenhum livro no momento.'),
        for (final e in ativos)
          CartaoEmprestimo(e, onTap: () => acoesEmprestimo(context, e)),
        if (reservas.isNotEmpty) ...[
          const Secao('Na fila de espera'),
          for (final r in reservas)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.hourglass_top),
              title: Text(loja.tituloLivro(r.livroId)),
              subtitle: Text('Desde ${fmtData(r.criadaEm)}${r.status == 'avisado' ? ' · já avisado' : ''}'),
              onTap: () => abrir(context, (c) => DetalheLivro(r.livroId)),
            ),
        ],
        if (deps.isNotEmpty) ...[
          const Secao('Crianças sob responsabilidade'),
          for (final d in deps)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.child_care),
              title: Text(d.nome),
              subtitle: Text('${loja.ativosDoLeitor(d.id).length} livro(s) agora'),
              onTap: () => abrir(context, (c) => DetalheLeitor(d.id)),
            ),
        ],
        Secao('Histórico (${historico.length})'),
        if (historico.isEmpty) const Text('Nenhum livro devolvido ainda.'),
        for (final e in historico)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(loja.tituloLivro(e.livroId, e.livroTitulo)),
            subtitle: Text('${fmtData(e.retiradaEm)} → ${fmtData(e.devolvidoEm)}'),
          ),
        const SizedBox(height: 16),
        Text('Cadastrado em ${fmtData(l.criadoEm)} · consentimento em ${fmtData(l.consentimentoEm)}',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 32),
      ]),
    );
  }
}

/// Cadastro/edição de leitor. Ao criar, devolve o novo leitor com Navigator.pop.
class FormLeitor extends StatefulWidget {
  final Leitor? leitor;
  const FormLeitor({super.key, this.leitor});

  @override
  State<FormLeitor> createState() => _FormLeitorState();
}

class _FormLeitorState extends State<FormLeitor> {
  late final bool novo = widget.leitor == null;
  late final nome = TextEditingController(text: widget.leitor?.nome ?? '');
  late final telefone = TextEditingController(text: widget.leitor?.telefone ?? '');
  late final email = TextEditingController(text: widget.leitor?.email ?? '');
  late final grupo = TextEditingController(text: widget.leitor?.grupo ?? '');
  late final obs = TextEditingController(text: widget.leitor?.obs ?? '');
  late String responsavelId = widget.leitor?.responsavelId ?? '';
  late bool menor = widget.leitor?.menor ?? false;
  late bool consentiu = widget.leitor?.consentimentoEm != null;
  bool salvando = false;

  Future<void> _salvar() async {
    if (nome.text.trim().isEmpty) {
      mostrarAviso(context, 'Informe o nome.');
      return;
    }
    if (menor && responsavelId.isEmpty) {
      mostrarAviso(context, 'Escolha o responsável pela criança.');
      return;
    }
    if (!menor && telefone.text.trim().isEmpty) {
      mostrarAviso(context, 'Informe o telefone/WhatsApp.');
      return;
    }
    if (!consentiu) {
      mostrarAviso(context, 'Confirme que a pessoa autorizou o cadastro.');
      return;
    }
    final l = Leitor(
      id: widget.leitor?.id ?? loja.novoId('leitores'),
      nome: nome.text,
      telefone: telefone.text,
      email: email.text,
      grupo: grupo.text,
      obs: obs.text,
      responsavelId: menor ? responsavelId : '',
      consentimentoEm: widget.leitor?.consentimentoEm ?? DateTime.now(),
      criadoEm: widget.leitor?.criadoEm ?? DateTime.now(),
    );
    setState(() => salvando = true);
    final ok = await executar(context, () => loja.salvarLeitor(l, novo: novo), sucesso: novo ? 'Leitor cadastrado!' : 'Alterações salvas.');
    if (!mounted) return;
    setState(() => salvando = false);
    if (ok) Navigator.pop(context, l);
  }

  @override
  Widget build(BuildContext context) {
    const espaco = SizedBox(height: 14);
    final resp = loja.leitores[responsavelId];
    return Scaffold(
      appBar: AppBar(title: Text(novo ? 'Novo leitor' : 'Editar leitor')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: nome, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nome *')),
        espaco,
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('É criança / menor de idade'),
          subtitle: const Text('Fica ligada a um responsável, que recebe os avisos'),
          value: menor,
          onChanged: (v) => setState(() => menor = v),
        ),
        if (menor) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.family_restroom),
              title: Text(resp?.nome ?? 'Escolher responsável *'),
              subtitle: resp == null ? const Text('O responsável precisa estar cadastrado') : const Text('Toque para trocar'),
              onTap: () async {
                final r = await escolherLeitor(context, titulo: 'Responsável', somenteAdultos: true);
                if (r != null && r.id != widget.leitor?.id) setState(() => responsavelId = r.id);
              },
            ),
          ),
          espaco,
        ],
        TextField(
          controller: telefone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: menor ? 'Telefone/WhatsApp (opcional)' : 'Telefone/WhatsApp *',
            hintText: '(11) 98765-4321',
            helperText: menor ? 'Se vazio, usamos o telefone do responsável' : null,
          ),
        ),
        espaco,
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail (opcional)')),
        espaco,
        TextField(
            controller: grupo,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Ministério ou grupo (opcional)', hintText: 'Ex.: Jovens, Louvor, EBD')),
        espaco,
        TextField(controller: obs, maxLines: 2, decoration: const InputDecoration(labelText: 'Observações (opcional)')),
        espaco,
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: consentiu,
          onChanged: (v) => setState(() => consentiu = v ?? false),
          title: Text(menor
              ? 'O responsável autorizou guardar estes dados para os empréstimos *'
              : 'A pessoa autorizou guardar estes dados para os empréstimos *'),
          subtitle: const Text('Usados só pela biblioteca. Podem ser apagados a qualquer momento, a pedido.'),
        ),
        const SizedBox(height: 16),
        BotaoGrande(Icons.save, salvando ? 'Salvando...' : 'Salvar', salvando ? null : _salvar),
        const SizedBox(height: 24),
      ]),
    );
  }
}
