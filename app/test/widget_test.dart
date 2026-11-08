import 'package:flutter_test/flutter_test.dart';

import 'package:biblioteca/util.dart';

void main() {
  test('normaliza acentos para busca', () {
    expect(normalizar('Bíblia São João'), 'biblia sao joao');
    expect(corresponde('biblia joao', ['Bíblia de São João']), isTrue);
  });

  test('formata número para WhatsApp', () {
    expect(numeroWhatsApp('(11) 98765-4321'), '5511987654321');
    expect(numeroWhatsApp(''), isNull);
  });
}
