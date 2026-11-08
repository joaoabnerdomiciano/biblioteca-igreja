// =====================================================================
//  CONFIGURAÇÃO — edite este arquivo uma única vez (veja o README.md)
// =====================================================================
import 'package:firebase_core/firebase_core.dart';

/// E-mail de quem administra a biblioteca. Só esta pessoa pode excluir
/// livros e leitores, mudar as configurações e liberar voluntários.
/// Precisa ser IGUAL ao e-mail colocado no arquivo firestore.rules.
const String emailAdministrador = 'joaoabner2019@gmail.com';

/// Dados do app Android cadastrado no Firebase
/// (Console do Firebase > Configurações do projeto > Seus apps > Android).
/// Estes valores não são segredos: a proteção fica nas regras do Firestore.
const FirebaseOptions opcoesFirebase = FirebaseOptions(
  apiKey: 'AIzaSyDw9PCuKA8WfRyUSd4oAb3HHcZcNOeLmXY',
  appId: '1:992191695101:android:6acf14015e5764f3fa9694',
  messagingSenderId: '992191695101',
  projectId: 'biblioteca-igreja-adcs',
);

bool get firebaseConfigurado => !opcoesFirebase.apiKey.startsWith('COLE-AQUI');
