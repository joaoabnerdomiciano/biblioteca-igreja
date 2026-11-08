// Busca dados de um livro pelo ISBN em bases gratuitas.
// Ordem: BrasilAPI (boa para editoras brasileiras) → Google Books → Open Library.
import 'dart:convert';

import 'package:http/http.dart' as http;

class DadosIsbn {
  String titulo = '', autor = '', editora = '', sinopse = '', capaUrl = '';
  int? ano;
  bool get vazio => titulo.isEmpty;
}

String limparIsbn(String isbn) => isbn.replaceAll(RegExp(r'[^0-9Xx]'), '').toUpperCase();

Future<Map<String, dynamic>?> _json(String url) async {
  try {
    final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) return null;
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    return d is Map<String, dynamic> ? d : null;
  } catch (_) {
    return null;
  }
}

int? _ano(dynamic v) {
  final m = RegExp(r'\d{4}').firstMatch(v?.toString() ?? '');
  return m == null ? null : int.tryParse(m.group(0)!);
}

String _https(String url) => url.replaceFirst('http://', 'https://');

Future<DadosIsbn?> buscarIsbn(String isbnBruto) async {
  final isbn = limparIsbn(isbnBruto);
  if (isbn.length != 10 && isbn.length != 13) return null;
  final r = DadosIsbn();

  final b = await _json('https://brasilapi.com.br/api/isbn/v1/$isbn');
  if (b != null && (b['title'] ?? '').toString().isNotEmpty) {
    r.titulo = [b['title'], b['subtitle']].where((x) => x != null && x.toString().isNotEmpty).join(': ');
    r.autor = (b['authors'] is List) ? (b['authors'] as List).join(', ') : '';
    r.editora = (b['publisher'] ?? '').toString();
    r.sinopse = (b['synopsis'] ?? '').toString();
    r.ano = _ano(b['year']);
    r.capaUrl = _https((b['cover_url'] ?? '').toString());
  }

  if (r.vazio || r.capaUrl.isEmpty) {
    final g = await _json('https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn');
    final itens = g?['items'];
    if (itens is List && itens.isNotEmpty) {
      final v = (itens.first as Map)['volumeInfo'] as Map? ?? {};
      if (r.vazio) {
        r.titulo = [v['title'], v['subtitle']].where((x) => x != null).join(': ');
        r.autor = (v['authors'] is List) ? (v['authors'] as List).join(', ') : '';
        r.editora = (v['publisher'] ?? '').toString();
        r.sinopse = (v['description'] ?? '').toString();
        r.ano = _ano(v['publishedDate']);
      }
      final imgs = v['imageLinks'];
      if (r.capaUrl.isEmpty && imgs is Map && imgs['thumbnail'] != null) r.capaUrl = _https(imgs['thumbnail'].toString());
    }
  }

  if (r.vazio) {
    final o = await _json('https://openlibrary.org/api/books?bibkeys=ISBN:$isbn&format=json&jscmd=data');
    final d = o?['ISBN:$isbn'];
    if (d is Map) {
      r.titulo = (d['title'] ?? '').toString();
      r.autor = (d['authors'] is List) ? (d['authors'] as List).map((a) => (a as Map)['name']).join(', ') : '';
      r.editora = (d['publishers'] is List && (d['publishers'] as List).isNotEmpty)
          ? ((d['publishers'] as List).first as Map)['name'].toString()
          : '';
      r.ano = _ano(d['publish_date']);
      final capa = d['cover'];
      if (r.capaUrl.isEmpty && capa is Map && capa['medium'] != null) r.capaUrl = _https(capa['medium'].toString());
    }
  }
  return r.vazio ? null : r;
}
