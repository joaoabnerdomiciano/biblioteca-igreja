# Biblioteca da Igreja

Sistema simples para a biblioteca da igreja, em duas partes:

| Parte | Pasta | Quem usa | Onde roda |
|---|---|---|---|
| **App de gestão** (Flutter) | `app/` | Voluntários | Celular Android |
| **Catálogo público** (HTML) | `docs/` | Qualquer pessoa, sem cadastro | GitHub Pages |

Os dois usam o mesmo banco de dados no **Firebase** (plano gratuito).

```
Celular do voluntário (app Flutter)
        │  login + leitura/escrita
        ▼
Firebase (banco Firestore + login)
        │  leitura pública só da lista de livros
        ▼
Catálogo no GitHub Pages (sem login)
```

---

## O que o app faz

- **Início:** livros emprestados, atrasados, que vencem na semana, sugestões do mês, mais lidos e leitores mais ativos.
- **Emprestar:** em 3 passos (leitor → livro → confirmar). Respeita o limite de livros por pessoa e avisa se existe fila para aquele livro.
- **Devolver:** busca por código, livro ou leitor. Também renova o empréstimo, manda lembrete pelo WhatsApp e, quando alguém está na fila do livro devolvido, avisa na hora.
- **Acervo:** busca e filtros. No cadastro, o ISBN preenche os dados sozinho; a capa vem da internet ou de uma foto tirada no celular. Cada cópia física é um exemplar com código próprio (BIB-0001…), origem (comprado, doado ou cedido) e situação.
- **Leitores:** cadastro com consentimento (LGPD). Crianças ficam ligadas a um responsável, que recebe os avisos. Cada leitor tem seu histórico.
- **Fila de espera** por livro.
- **Relatórios:** empréstimos por mês, categorias mais procuradas e livros nunca emprestados. Acervo e empréstimos podem ser exportados em CSV (Excel ou Google Planilhas).
- **Administração (só você):** excluir livros e leitores, alterar configurações e liberar voluntários.

Regras padrão: prazo de 14 dias, 1 renovação, 2 livros por pessoa e sem multas. Para mudar, use **Mais › Configurações**.

---

## Instalação passo a passo (uma vez só, cerca de 30 minutos)

### 1. GitHub
1. Crie uma conta em https://github.com, se ainda não tiver.
2. Crie um repositório **público**, por exemplo `biblioteca-igreja`.
3. Envie todos os arquivos deste projeto. Pelo site, em *Add file › Upload files*, você pode arrastar as pastas `app`, `docs`, `.github` e os arquivos soltos.
   > A pasta `.github` começa com ponto e pode estar oculta no seu computador. Ela é necessária para gerar o APK.

### 2. Firebase
1. Acesse https://console.firebase.google.com com sua conta Google e clique em **Criar projeto**. O Google Analytics pode ser desativado.
2. **Authentication › Começar › E-mail/senha › Ativar**.
3. **Firestore Database › Criar banco de dados** → local `southamerica-east1 (São Paulo)` → **modo de produção**.
4. Na aba **Regras** do Firestore, apague o conteúdo e cole o arquivo `firestore.rules` deste projeto. Troque `SEU-EMAIL@gmail.com` pelo seu e-mail e clique em **Publicar**.
5. Vá em **Configurações do projeto** (ícone de engrenagem) e cadastre dois apps:
   - **Android:** nome do pacote `br.org.igreja.biblioteca`. Clique em avançar até terminar; não precisa adicionar nada ao código. Depois, baixe o `google-services.json` só para copiar estes valores:
     - `current_key` → `apiKey`
     - `mobilesdk_app_id` → `appId`
     - `project_number` → `messagingSenderId`
     - `project_id` → `projectId`
   - **Web** (ícone `</>`): o Firebase mostra um bloco `firebaseConfig`. Guarde-o para o passo 3.

### 3. Ligar o código ao Firebase
Edite os arquivos direto pelo site do GitHub (clique no arquivo e depois no lápis):
- `app/lib/config.dart`: seu e-mail de administrador e os 4 valores do app **Android**.
- `docs/config.js`: o nome da biblioteca e os valores do app **Web**.

> Esses valores não são senhas. Quem protege os dados são as regras do passo 2.4.

### 4. Chave de assinatura do APK (recomendado)
Sem essa chave, cada nova versão do APK sai com uma assinatura diferente, e o celular obriga a desinstalar o app antigo antes de instalar o novo.

No seu computador, com Java instalado, rode:
```bash
keytool -genkeypair -v -keystore debug.keystore -storepass android -alias androiddebugkey \
  -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Biblioteca,O=Igreja,C=BR"
```
Depois, converta a chave para texto:
- Linux: `base64 -w0 debug.keystore`
- Mac: `base64 -i debug.keystore`
- Windows (PowerShell): `[Convert]::ToBase64String([IO.File]::ReadAllBytes("debug.keystore"))`

No GitHub, vá em **Settings › Secrets and variables › Actions › New repository secret**, crie o nome `KEYSTORE_B64` e cole o texto gerado. Guarde o arquivo `debug.keystore` em lugar seguro.

### 5. Gerar o APK
1. Abra a aba **Actions** do repositório, escolha **Gerar APK** e clique em **Run workflow**. Leva uns 8 minutos.
2. Quando terminar, abra a aba **Releases** e baixe o `biblioteca.apk` pelo celular.
3. Abra o arquivo e permita a instalação de *fontes desconhecidas*, se o Android pedir.

Toda alteração que você salvar na pasta `app/` gera uma versão nova automaticamente.

### 6. Publicar o catálogo
Em **Settings › Pages**, escolha *Deploy from a branch*, branch `main`, pasta `/docs`, e salve. Depois de 1 ou 2 minutos, o catálogo estará em:
`https://SEU-USUARIO.github.io/biblioteca-igreja/`

Compartilhe esse link no grupo da igreja ou gere um QR Code para colar na estante.

### 7. Primeiro uso
1. Abra o app, toque em **Criar conta** com o **seu** e-mail (o de administrador) e confirme pelo link que chegar por e-mail.
2. Para testar, use **Mais › Dados de exemplo**. Isso carrega 20 livros e 8 leitores. Depois exclua os exemplos e cadastre o acervo real.
3. Em **Mais › Voluntários**, libere o e-mail de cada voluntário. Cada um instala o APK, cria a conta com esse e-mail e confirma pelo link.

---

## Fazendo correções no código

```
app/lib/
  config.dart        ← e-mail do administrador e chaves do Firebase
  modelos.dart       ← estrutura dos dados (Livro, Exemplar, Leitor...)
  loja.dart          ← toda a lógica: emprestar, devolver, renovar, excluir...
  util.dart          ← datas, WhatsApp, buscas sem acento
  isbn.dart          ← busca de dados pelo ISBN
  componentes.dart   ← peças visuais reutilizadas (capa, botões...)
  exemplos.dart      ← dados de exemplo
  telas/             ← uma tela por arquivo (inicio, emprestar, devolver, acervo, leitores, mais)
docs/                ← catálogo público (HTML/CSS/JS puro)
firestore.rules      ← quem pode ler e escrever o quê
```

Para rodar no seu computador: `cd app`, depois `flutter create --platforms=android --org br.org.igreja --project-name biblioteca .` (só na primeira vez) e `flutter run`. Pelo GitHub também funciona: edite o arquivo no site, salve, e o APK novo aparece em *Releases*.

## Dados guardados no Firebase

| Coleção | Conteúdo | Quem lê |
|---|---|---|
| `livros` | título, autor, categoria, estante, disponíveis/total, destaque | **público** (catálogo) |
| `capas` | foto da capa reduzida | **público** |
| `exemplares` | código BIB, origem (com doador ou dono), situação | voluntários |
| `leitores` | nome, telefone, e-mail, grupo, responsável, consentimento | voluntários |
| `emprestimos` | quem, qual exemplar, datas, renovações | voluntários |
| `reservas` | fila de espera | voluntários |
| `config` | prazo, limite, mensagens, contador de códigos | voluntários (só o admin altera) |
| `voluntarios` | e-mails liberados | admin |

## Custos e limites
O plano gratuito do Firebase (Spark) permite 50 mil leituras e 20 mil gravações por dia, mais que suficiente para uma biblioteca de igreja. Cada visita ao catálogo lê cerca de uma vez cada livro (aprox. 200 leituras), então o limite comporta mais de 200 visitas por dia. GitHub e GitHub Pages também são gratuitos.

## Limitações conhecidas
- O WhatsApp abre com a mensagem pronta, mas quem envia é o voluntário (o app não envia mensagens sozinho).
- A busca por ISBN usa bases gratuitas (BrasilAPI, Google Books e Open Library). Livros de editoras pequenas podem não aparecer; nesse caso, preencha à mão.
- O app foi feito para Android.
- O app precisa de internet para registrar empréstimos.
