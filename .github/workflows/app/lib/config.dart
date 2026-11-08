// =====================================================================
//  CONFIGURAÇÃO — edite este arquivo uma única vez (veja o README.md)
// =====================================================================
import 'package:firebase_core/firebase_core.dart';

/// E-mail de quem administra a biblioteca. Só esta pessoa pode excluir
/// livros e leitores, mudar as configurações e liberar voluntários.
/// Precisa ser IGUAL ao e-mail colocado no arquivo firestore.rules.
const String emailAdministrador = 'SEU-EMAIL@gmail.com';

/// Dados do app Android cadastrado no Firebase
/// (Console do Firebase > Configurações do projeto > Seus apps > Android).
/// Estes valores não são segredos: a proteção fica nas regras do Firestore.
const FirebaseOptions opcoesFirebase = FirebaseOptions(
  apiKey: 'COLE-AQUI-A-API-KEY',
  appId: 'COLE-AQUI-O-APP-ID',
  messagingSenderId: 'COLE-AQUI-O-SENDER-ID',
  projectId: 'COLE-AQUI-O-PROJECT-ID',
);

bool get firebaseConfigurado => !opcoesFirebase.apiKey.startsWith('COLE-AQUI');
