import { CONFIG } from './config.js';

const FIREBASE_VERSAO = '10.12.2';
const CATEGORIAS = ['Bíblias', 'Teologia', 'Devocionais', 'Biografias cristãs', 'Família e casamento',
  'Infantil', 'Juvenil', 'Estudos bíblicos', 'Ficção cristã', 'Outros'];
const CORES = ['#8D4B2F', '#3F6B5B', '#4A5A8C', '#7A5C2E', '#6B3F6B', '#2F6F7A'];
const CHAVE_CACHE = 'catalogo-livros-v1';

const $ = (id) => document.getElementById(id);
const estado = { livros: [], categoria: null, busca: '', soDisponiveis: false };
let buscarCapa = async () => null;

// ---------- utilidades ----------
const normalizar = (s) => (s || '').toString().toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
const escapar = (s) => (s ?? '').toString().replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const hash = (s) => [...(s || '')].reduce((h, c) => (h * 31 + c.charCodeAt(0)) | 0, 0);
const iniciais = (t) => (t || '').split(/\s+/).filter((p) => p.length > 2).slice(0, 2).map((p) => p[0].toUpperCase()).join('') || '📖';

function capaHtml(livro, grande = false) {
  const cls = `capa${grande ? ' grande' : ''}`;
  if (livro.capaUrl) {
    return `<img class="${cls}" src="${escapar(livro.capaUrl)}" alt="" loading="lazy" data-fallback="${escapar(livro.id)}">`;
  }
  const cor = CORES[Math.abs(hash(livro.titulo)) % CORES.length];
  return `<div class="${cls}" style="background:${cor}" data-capa="${livro.temFoto ? escapar(livro.id) : ''}">${escapar(iniciais(livro.titulo))}</div>`;
}

function seloHtml(l) {
  if (l.disponiveis > 0) {
    const txt = l.total > 1 ? `Disponível (${l.disponiveis} de ${l.total})` : 'Disponível';
    return `<span class="selo ok">${txt}</span>`;
  }
  return '<span class="selo ocupado">Emprestado no momento</span>';
}

// Troca o quadrado colorido pela foto (para livros com foto tirada no app).
async function carregarFotos(raiz) {
  for (const el of raiz.querySelectorAll('[data-capa]:not([data-capa=""])')) {
    const id = el.dataset.capa;
    el.dataset.capa = '';
    const src = await buscarCapa(id);
    if (!src) continue;
    const img = document.createElement('img');
    img.className = el.className;
    img.alt = '';
    img.src = src;
    el.replaceWith(img);
  }
  for (const img of raiz.querySelectorAll('img[data-fallback]')) {
    img.addEventListener('error', () => {
      const l = estado.livros.find((x) => x.id === img.dataset.fallback);
      if (l) img.outerHTML = capaHtml({ ...l, capaUrl: '' }, img.classList.contains('grande'));
    }, { once: true });
  }
}

// ---------- desenho da página ----------
function desenharFiltros() {
  const usadas = new Set(estado.livros.map((l) => l.categoria));
  const cats = CATEGORIAS.filter((c) => usadas.has(c));
  $('filtros').innerHTML = ['Todas', ...cats].map((c) => {
    const ativo = (c === 'Todas' && !estado.categoria) || c === estado.categoria;
    return `<button type="button" data-cat="${escapar(c)}" aria-pressed="${ativo}">${escapar(c)}</button>`;
  }).join('');
}

function cartao(l) {
  return `<button type="button" class="livro" data-id="${escapar(l.id)}">
    ${capaHtml(l)}
    <div class="info">
      <div class="titulo">${escapar(l.titulo)}</div>
      ${l.autor ? `<div class="autor">${escapar(l.autor)}</div>` : ''}
      <div class="meta">${seloHtml(l)}${l.estante ? `<span class="estante">Estante ${escapar(l.estante)}</span>` : ''}</div>
    </div>
  </button>`;
}

function desenharLista() {
  const b = normalizar(estado.busca).trim().split(/\s+/).filter(Boolean);
  const lista = estado.livros.filter((l) => {
    if (estado.categoria && l.categoria !== estado.categoria) return false;
    if (estado.soDisponiveis && !(l.disponiveis > 0)) return false;
    const alvo = normalizar(`${l.titulo} ${l.autor} ${l.editora}`);
    return b.every((p) => alvo.includes(p));
  });
  $('lista').innerHTML = lista.map(cartao).join('');
  $('vazio').hidden = lista.length > 0;
  $('titulo-lista').textContent = estado.categoria || (b.length ? 'Resultado da busca' : 'Todos os livros');
  carregarFotos($('lista'));

  const filtrando = b.length || estado.categoria || estado.soDisponiveis;
  const destaques = estado.livros.filter((l) => l.destaque);
  $('destaques').hidden = !destaques.length || filtrando;
  $('lista-destaques').innerHTML = destaques.map((l) => `
    <button type="button" class="destaque" data-id="${escapar(l.id)}">
      ${capaHtml(l)}
      <div class="info">
        <div class="titulo">${escapar(l.titulo)}</div>
        ${l.autor ? `<div class="autor">${escapar(l.autor)}</div>` : ''}
        ${l.destaqueNota ? `<div class="nota">“${escapar(l.destaqueNota)}”</div>` : ''}
        <div class="meta">${seloHtml(l)}</div>
      </div>
    </button>`).join('');
  carregarFotos($('lista-destaques'));
}

function abrirDetalhe(id) {
  const l = estado.livros.find((x) => x.id === id);
  if (!l) return;
  const linha = [l.editora, l.ano].filter(Boolean).map(escapar).join(' · ');
  $('detalhe-conteudo').innerHTML = `
    <div class="detalhe-topo">
      ${capaHtml(l, true)}
      <div>
        <h3>${escapar(l.titulo)}</h3>
        ${l.autor ? `<div class="autor">${escapar(l.autor)}</div>` : ''}
        ${linha ? `<div class="autor">${linha}</div>` : ''}
        <div class="autor">${escapar(l.categoria)}</div>
        <div class="meta">${seloHtml(l)}</div>
      </div>
    </div>
    ${l.destaqueNota && l.destaque ? `<div class="detalhe-nota">“${escapar(l.destaqueNota)}”</div>` : ''}
    ${l.sinopse ? `<div class="detalhe-sinopse">${escapar(l.sinopse)}</div>` : ''}
    <div class="detalhe-situacao">
      ${l.estante ? `Fica na <strong>estante ${escapar(l.estante)}</strong>. ` : ''}
      ${l.disponiveis > 0 ? 'Pode ser retirado hoje.' : 'Está com outro leitor agora. Peça à equipe para entrar na fila de espera.'}
    </div>`;
  carregarFotos($('detalhe-conteudo'));
  $('detalhe').showModal();
}

function aplicarDados(livros, demonstracao) {
  estado.livros = livros
    .filter((l) => (l.total || 0) > 0)
    .sort((a, b) => normalizar(a.titulo).localeCompare(normalizar(b.titulo)));
  const disp = estado.livros.filter((l) => l.disponiveis > 0).length;
  $('resumo').textContent = `${estado.livros.length} títulos · ${disp} disponíveis agora`;
  $('aviso-demo').hidden = !demonstracao;
  desenharFiltros();
  desenharLista();
}

// ---------- dados ----------
function lerCache() {
  try { return JSON.parse(localStorage.getItem(CHAVE_CACHE) || 'null'); } catch { return null; }
}
function gravarCache(livros) {
  try { localStorage.setItem(CHAVE_CACHE, JSON.stringify(livros)); } catch { /* sem espaço ou bloqueado */ }
}

async function carregar() {
  $('nome').textContent = CONFIG.nomeBiblioteca;
  document.title = `Catálogo — ${CONFIG.nomeBiblioteca}`;
  $('como-pegar').textContent = CONFIG.comoPegar;

  const configurado = CONFIG.firebase?.apiKey && !CONFIG.firebase.apiKey.startsWith('COLE');
  if (!configurado) {
    const { LIVROS_DEMONSTRACAO } = await import('./demonstracao.js');
    aplicarDados(LIVROS_DEMONSTRACAO, true);
    return;
  }

  const cache = lerCache();
  if (cache) aplicarDados(cache, false);

  try {
    const { initializeApp } = await import(`https://www.gstatic.com/firebasejs/${FIREBASE_VERSAO}/firebase-app.js`);
    const fs = await import(`https://www.gstatic.com/firebasejs/${FIREBASE_VERSAO}/firebase-firestore.js`);
    const db = fs.getFirestore(initializeApp(CONFIG.firebase));
    const snap = await fs.getDocs(fs.collection(db, 'livros'));
    const livros = snap.docs.map((d) => {
      const x = d.data();
      return {
        id: d.id, titulo: x.titulo || '', autor: x.autor || '', editora: x.editora || '', ano: x.ano || null,
        categoria: x.categoria || 'Outros', estante: x.estante || '', sinopse: x.sinopse || '',
        capaUrl: x.capaUrl || '', temFoto: !!x.temFoto, destaque: !!x.destaque, destaqueNota: x.destaqueNota || '',
        total: x.total || 0, disponiveis: x.disponiveis || 0,
      };
    });
    const capas = new Map();
    buscarCapa = (id) => {
      if (!capas.has(id)) {
        capas.set(id, fs.getDoc(fs.doc(db, 'capas', id))
          .then((d) => (d.exists() && d.data().img ? `data:image/jpeg;base64,${d.data().img}` : null))
          .catch(() => null));
      }
      return capas.get(id);
    };
    gravarCache(livros);
    aplicarDados(livros, false);
  } catch (e) {
    console.error(e);
    if (!cache) $('resumo').textContent = 'Não foi possível carregar o catálogo agora. Tente de novo mais tarde.';
  }
}

// ---------- eventos ----------
$('busca').addEventListener('input', (e) => { estado.busca = e.target.value; desenharLista(); });
$('so-disponiveis').addEventListener('change', (e) => { estado.soDisponiveis = e.target.checked; desenharLista(); });
$('filtros').addEventListener('click', (e) => {
  const b = e.target.closest('button[data-cat]');
  if (!b) return;
  estado.categoria = b.dataset.cat === 'Todas' ? null : b.dataset.cat;
  desenharFiltros();
  desenharLista();
});
document.addEventListener('click', (e) => {
  const card = e.target.closest('button[data-id]');
  if (card) abrirDetalhe(card.dataset.id);
});
$('detalhe').addEventListener('click', (e) => { if (e.target === $('detalhe')) $('detalhe').close(); });

carregar();
