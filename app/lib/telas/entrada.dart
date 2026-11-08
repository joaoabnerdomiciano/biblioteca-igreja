// Telas de entrada: login, confirmação de e-mail e autorização.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../componentes.dart';
import '../loja.dart';
import 'inicio.dart';

class ConfiguracaoPendente extends StatelessWidget {
  const ConfiguracaoPendente({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Vazio(Icons.settings,
              'O app ainda não foi ligado ao Firebase.\n\nPreencha o arquivo lib/config.dart (veja o README) e gere o app de novo.'),
        ),
      );
}

/// Decide qual tela mostrar conforme a pessoa está logada ou não.
class Portao extends StatefulWidget {
  const Portao({super.key});

  @override
  State<Portao> createState() => _PortaoState();
}

class _PortaoState extends State<Portao> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (c, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final u = FirebaseAuth.instance.currentUser;
        if (u == null) return const TelaLogin();
        if (!u.emailVerified) return TelaVerificarEmail(aoVerificar: () => setState(() {}));
        return Autorizacao(key: ValueKey(u.uid), usuario: u);
      },
    );
  }
}

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final email = TextEditingController();
  final senha = TextEditingController();
  bool criando = false, ocupado = false, verSenha = false;
  String? erro;

  String _traduzir(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'E-mail inválido.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'E-mail ou senha incorretos.',
        'email-already-in-use' => 'Já existe uma conta com este e-mail. Use "Entrar".',
        'weak-password' => 'A senha precisa ter pelo menos 6 caracteres.',
        'network-request-failed' => 'Sem conexão com a internet.',
        'too-many-requests' => 'Muitas tentativas. Espere alguns minutos.',
        _ => 'Não foi possível entrar (${e.code}).',
      };

  Future<void> _enviar() async {
    setState(() {
      ocupado = true;
      erro = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (criando) {
        final cred = await auth.createUserWithEmailAndPassword(email: email.text.trim(), password: senha.text);
        await cred.user?.sendEmailVerification();
      } else {
        await auth.signInWithEmailAndPassword(email: email.text.trim(), password: senha.text);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => erro = _traduzir(e));
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<void> _esqueci() async {
    if (!email.text.contains('@')) {
      setState(() => erro = 'Digite seu e-mail primeiro.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.text.trim());
      setState(() => erro = null);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Enviamos um e-mail para você criar uma nova senha.')));
      }
    } on FirebaseAuthException catch (e) {
      setState(() => erro = _traduzir(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 32),
          Icon(Icons.menu_book_rounded, size: 72, color: t.colorScheme.primary),
          const SizedBox(height: 12),
          Text('Biblioteca da Igreja', textAlign: TextAlign.center, style: t.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(criando ? 'Criar conta de voluntário' : 'Entrada dos voluntários',
              textAlign: TextAlign.center, style: t.textTheme.bodyLarge),
          const SizedBox(height: 32),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.email_outlined)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: senha,
            obscureText: !verSenha,
            onSubmitted: (_) => _enviar(),
            decoration: InputDecoration(
              labelText: 'Senha',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(verSenha ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => verSenha = !verSenha),
              ),
            ),
          ),
          if (erro != null) ...[
            const SizedBox(height: 12),
            Text(erro!, style: TextStyle(color: t.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          BotaoGrande(criando ? Icons.person_add : Icons.login, criando ? 'Criar conta' : 'Entrar',
              ocupado ? null : _enviar),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              criando = !criando;
              erro = null;
            }),
            child: Text(criando ? 'Já tenho conta — entrar' : 'Primeira vez? Criar conta'),
          ),
          if (!criando) TextButton(onPressed: _esqueci, child: const Text('Esqueci minha senha')),
        ]),
      ),
    );
  }
}

class TelaVerificarEmail extends StatefulWidget {
  final VoidCallback aoVerificar;
  const TelaVerificarEmail({super.key, required this.aoVerificar});

  @override
  State<TelaVerificarEmail> createState() => _TelaVerificarEmailState();
}

class _TelaVerificarEmailState extends State<TelaVerificarEmail> {
  String? msg;

  Future<void> _jaConfirmei() async {
    final u = FirebaseAuth.instance.currentUser;
    await u?.reload();
    final atual = FirebaseAuth.instance.currentUser;
    if (atual != null && atual.emailVerified) {
      await atual.getIdToken(true); // atualiza a permissão no banco
      widget.aoVerificar();
    } else {
      setState(() => msg = 'Ainda não aparece como confirmado. Abra o link do e-mail e tente de novo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 48),
          const Icon(Icons.mark_email_unread_outlined, size: 72),
          const SizedBox(height: 16),
          Text('Confirme seu e-mail', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text('Enviamos um link para $email. Abra o e-mail (veja também o spam) e toque no link.',
              textAlign: TextAlign.center),
          if (msg != null) ...[const SizedBox(height: 12), Text(msg!, textAlign: TextAlign.center)],
          const SizedBox(height: 24),
          BotaoGrande(Icons.check, 'Já confirmei', _jaConfirmei),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.currentUser?.sendEmailVerification();
              setState(() => msg = 'E-mail reenviado.');
            },
            child: const Text('Reenviar e-mail'),
          ),
          TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Sair')),
        ]),
      ),
    );
  }
}

/// Confere se o e-mail foi liberado pelo administrador e abre o app.
class Autorizacao extends StatefulWidget {
  final User usuario;
  const Autorizacao({super.key, required this.usuario});

  @override
  State<Autorizacao> createState() => _AutorizacaoState();
}

class _AutorizacaoState extends State<Autorizacao> {
  bool? liberado;
  String? erro;

  @override
  void initState() {
    super.initState();
    _verificar();
  }

  Future<void> _verificar() async {
    setState(() {
      liberado = null;
      erro = null;
    });
    final email = (widget.usuario.email ?? '').toLowerCase();
    final ehAdmin = Loja.ehAdministrador(email);
    var ok = ehAdmin;
    if (!ok) {
      try {
        final d = await FirebaseFirestore.instance.collection('voluntarios').doc(email).get();
        ok = d.exists;
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') erro = 'Sem conexão. Tente de novo.';
      }
    }
    if (ok) loja.iniciar(ehAdmin: ehAdmin);
    if (mounted) setState(() => liberado = ok);
  }

  @override
  void dispose() {
    loja.parar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (liberado == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (liberado == true) return const Inicio();
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 48),
          const Icon(Icons.hourglass_top, size: 72),
          const SizedBox(height: 16),
          Text('Quase lá!', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            erro ??
                'Seu e-mail (${widget.usuario.email}) ainda não foi liberado.\n\n'
                    'Peça ao responsável pela biblioteca para adicioná-lo em Mais > Voluntários.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          BotaoGrande(Icons.refresh, 'Tentar de novo', _verificar),
          const SizedBox(height: 12),
          TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Sair')),
        ]),
      ),
    );
  }
}
