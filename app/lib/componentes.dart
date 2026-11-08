import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'loja.dart';
import 'modelos.dart';
import 'util.dart';

/// Reconstrói o conteúdo sempre que os dados da biblioteca mudam.
class Ouvinte extends StatelessWidget {
  final WidgetBuilder builder;
  const Ouvinte({super.key, required this.builder});

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: loja, builder: (c, _) => builder(c));
}

/// Abre uma tela nova que acompanha as mudanças dos dados.
Future<T?> abrir<T>(BuildContext context, WidgetBuilder builder) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (c) => Ouvinte(builder: builder)));

const _coresCapa = [
  Color(0xFF8D4B2F),
  Color(0xFF3F6B5B),
  Color(0xFF4A5A8C),
  Color(0xFF7A5C2E),
  Color(0xFF6B3F6B),
  Color(0xFF2F6F7A),
];

class Capa extends StatelessWidget {
  final Livro livro;
  final double largura;
  const Capa(this.livro, {super.key, this.largura = 48});

  Widget _modelo(BuildContext context) {
    final cor = _coresCapa[livro.titulo.hashCode.abs() % _coresCapa.length];
    final iniciais = livro.titulo
        .split(RegExp(r'\s+'))
        .where((p) => p.length > 2)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return Container(
      width: largura,
      height: largura * 1.45,
      decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(6)),
      alignment: Alignment.center,
      child: Text(iniciais.isEmpty ? '📖' : iniciais,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: largura * 0.32)),
    );
  }

  Widget _imagem(ImageProvider img, BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image(
          image: img,
          width: largura,
          height: largura * 1.45,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => _modelo(context),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (livro.temFoto) {
      return FutureBuilder<Uint8List?>(
        future: loja.capa(livro.id),
        builder: (c, s) => s.data != null ? _imagem(MemoryImage(s.data!), c) : _modelo(c),
      );
    }
    if (livro.capaUrl.isNotEmpty) return _imagem(NetworkImage(livro.capaUrl), context);
    return _modelo(context);
  }
}

class Secao extends StatelessWidget {
  final String titulo;
  final Widget? acao;
  const Secao(this.titulo, {super.key, this.acao});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Row(children: [
          Expanded(
              child: Text(titulo,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
          if (acao != null) acao!,
        ]),
      );
}

class Vazio extends StatelessWidget {
  final IconData icone;
  final String texto;
  const Vazio(this.icone, this.texto, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icone, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(texto, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
        ]),
      );
}

class BotaoGrande extends StatelessWidget {
  final IconData icone;
  final String texto;
  final VoidCallback? onPressed;
  final bool contorno;
  const BotaoGrande(this.icone, this.texto, this.onPressed, {super.key, this.contorno = false});

  @override
  Widget build(BuildContext context) {
    final estilo = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(56)),
      textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
    );
    return contorno
        ? OutlinedButton.icon(style: estilo, onPressed: onPressed, icon: Icon(icone), label: Text(texto))
        : FilledButton.icon(style: estilo, onPressed: onPressed, icon: Icon(icone), label: Text(texto));
  }
}

class CampoBusca extends StatelessWidget {
  final TextEditingController controller;
  final String dica;
  final VoidCallback aoMudar;
  const CampoBusca(this.controller, this.dica, this.aoMudar, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: TextField(
          controller: controller,
          onChanged: (_) => aoMudar(),
          decoration: InputDecoration(
            hintText: dica,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      controller.clear();
                      aoMudar();
                    }),
            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
            isDense: true,
          ),
        ),
      );
}

/// Etiqueta colorida (ex.: "Atrasado", "Disponível").
class Etiqueta extends StatelessWidget {
  final String texto;
  final Color cor;
  const Etiqueta(this.texto, this.cor, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: cor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
        child: Text(texto, style: TextStyle(color: cor, fontWeight: FontWeight.w600, fontSize: 12.5)),
      );
}

const corOk = Color(0xFF2E7D32);
const corAlerta = Color(0xFFC62828);
const corAtencao = Color(0xFFB26A00);

Widget etiquetaPrazo(Emprestimo e) {
  if (e.prevista == null) return const SizedBox.shrink();
  final d = diasEntre(hoje(), e.prevista!);
  if (d < 0) return Etiqueta('Atrasado ${-d} dia${d == -1 ? '' : 's'}', corAlerta);
  if (d == 0) return const Etiqueta('Vence hoje', corAtencao);
  if (d <= 3) return Etiqueta('Vence em $d dia${d == 1 ? '' : 's'}', corAtencao);
  return Etiqueta('Até ${fmtDataCurta(e.prevista)}', corOk);
}

/// Tela de escolha de leitor com busca. Retorna o leitor escolhido.
Future<Leitor?> escolherLeitor(BuildContext context, {String titulo = 'Escolher leitor', bool somenteAdultos = false}) {
  return abrir<Leitor>(context, (c) => _EscolherLeitor(titulo, somenteAdultos));
}

class _EscolherLeitor extends StatefulWidget {
  final String titulo;
  final bool somenteAdultos;
  const _EscolherLeitor(this.titulo, this.somenteAdultos);

  @override
  State<_EscolherLeitor> createState() => _EscolherLeitorState();
}

class _EscolherLeitorState extends State<_EscolherLeitor> {
  final busca = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final lista = loja.leitoresOrdenados
        .where((l) => !widget.somenteAdultos || !l.menor)
        .where((l) => corresponde(busca.text, [l.nome, l.grupo]))
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: Column(children: [
        CampoBusca(busca, 'Buscar pelo nome', () => setState(() {})),
        Expanded(
          child: lista.isEmpty
              ? const Vazio(Icons.person_search, 'Ninguém encontrado.')
              : ListView.builder(
                  itemCount: lista.length,
                  itemBuilder: (c, i) => ListTile(
                    leading: CircleAvatar(child: Text(lista[i].nome.isEmpty ? '?' : lista[i].nome[0].toUpperCase())),
                    title: Text(lista[i].nome),
                    subtitle: lista[i].grupo.isEmpty ? null : Text(lista[i].grupo),
                    onTap: () => Navigator.pop(context, lista[i]),
                  ),
                ),
        ),
      ]),
    );
  }
}
