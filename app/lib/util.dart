import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Erro com mensagem amigável para mostrar ao voluntário.
class AvisoErro implements Exception {
  final String mensagem;
  AvisoErro(this.mensagem);
  @override
  String toString() => mensagem;
}

String _2(int n) => n.toString().padLeft(2, '0');

String fmtData(DateTime? d) => d == null ? '-' : '${_2(d.day)}/${_2(d.month)}/${d.year}';
String fmtDataCurta(DateTime? d) => d == null ? '-' : '${_2(d.day)}/${_2(d.month)}';

const nomesMeses = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

DateTime hoje() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime soData(DateTime d) => DateTime(d.year, d.month, d.day);

/// Dias de b - a, ignorando as horas.
int diasEntre(DateTime a, DateTime b) => soData(b).difference(soData(a)).inDays;

String primeiroNome(String nome) {
  final p = nome.trim().split(RegExp(r'\s+'));
  return p.isEmpty ? nome : p.first;
}

const _comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
const _semAcento = 'aaaaaeeeeiiiiooooouuuucn';

/// Minúsculas e sem acentos, para buscas.
String normalizar(String s) {
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = _comAcento.indexOf(ch);
    b.write(i >= 0 ? _semAcento[i] : ch);
  }
  return b.toString();
}

/// Verdadeiro se todas as palavras da busca aparecem em algum dos textos.
bool corresponde(String busca, List<String> textos) {
  final b = normalizar(busca.trim());
  if (b.isEmpty) return true;
  final alvo = normalizar(textos.join(' '));
  return b.split(RegExp(r'\s+')).every(alvo.contains);
}

/// Converte "(11) 98765-4321" em "5511987654321".
String? numeroWhatsApp(String telefone) {
  var d = telefone.replaceAll(RegExp(r'\D'), '');
  if (d.isEmpty) return null;
  if (d.startsWith('0')) d = d.substring(1);
  if (d.length == 10 || d.length == 11) d = '55$d';
  return d;
}

Future<void> abrirWhatsApp(BuildContext context, String telefone, String mensagem) async {
  final n = numeroWhatsApp(telefone);
  if (n == null) {
    mostrarAviso(context, 'Esta pessoa não tem telefone cadastrado.');
    return;
  }
  final uri = Uri.parse('https://wa.me/$n?text=${Uri.encodeComponent(mensagem)}');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) mostrarAviso(context, 'Não consegui abrir o WhatsApp.');
}

String preencherModelo(String modelo, Map<String, String> valores) {
  var r = modelo;
  valores.forEach((k, v) => r = r.replaceAll('{$k}', v));
  return r;
}

void mostrarAviso(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

Future<bool> confirmar(BuildContext context, String titulo, String mensagem,
    {String ok = 'Confirmar', bool perigo = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titulo),
      content: Text(mensagem),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
        FilledButton(
          style: perigo ? FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r == true;
}

/// Traduz erros técnicos em mensagens simples.
String mensagemDeErro(Object e) {
  if (e is AvisoErro) return e.mensagem;
  if (e is FirebaseException) {
    switch (e.code) {
      case 'permission-denied':
        return 'Você não tem permissão para fazer isso.';
      case 'unavailable':
        return 'Sem conexão com a internet. Tente de novo em instantes.';
      case 'aborted':
        return 'Outra pessoa alterou isso ao mesmo tempo. Tente de novo.';
    }
    return 'Algo deu errado (${e.code}). Tente de novo.';
  }
  return 'Algo deu errado: $e';
}

/// Executa uma ação mostrando o erro de forma amigável. Retorna true se deu certo.
Future<bool> executar(BuildContext context, Future<void> Function() acao, {String? sucesso}) async {
  try {
    await acao();
    if (sucesso != null) mostrarAviso(context, sucesso);
    return true;
  } catch (e) {
    mostrarAviso(context, mensagemDeErro(e));
    return false;
  }
}
