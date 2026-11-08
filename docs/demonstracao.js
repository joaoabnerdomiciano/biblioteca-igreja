// Livros fictícios usados só enquanto o Firebase não estiver configurado.
const l = (titulo, autor, categoria, estante, total, disponiveis, extra = {}) => ({
  id: titulo, titulo, autor, categoria, estante, total, disponiveis, editora: '', ano: null, sinopse: '',
  capaUrl: '', temFoto: false, destaque: false, destaqueNota: '', ...extra,
});

export const LIVROS_DEMONSTRACAO = [
  l('Bíblia Sagrada — Nova Versão Internacional', '', 'Bíblias', 'A1', 3, 3, { editora: 'Vida', ano: 2023 }),
  l('Bíblia de Estudo NAA', '', 'Bíblias', 'A1', 1, 1, { editora: 'SBB', ano: 2019 }),
  l('Cristianismo Puro e Simples', 'C. S. Lewis', 'Teologia', 'B1', 2, 2, {
    destaque: true, destaqueNota: 'Indicação do pastor para este mês', editora: 'Thomas Nelson Brasil', ano: 2017,
    sinopse: 'Uma das defesas mais conhecidas da fé cristã, escrita a partir de palestras de rádio durante a Segunda Guerra.',
  }),
  l('Conhecendo Deus', 'J. I. Packer', 'Teologia', 'B1', 1, 0),
  l('O Deus Pródigo', 'Timothy Keller', 'Teologia', 'B2', 1, 1),
  l('Mananciais no Deserto', 'L. B. Cowman', 'Devocionais', 'C1', 2, 2),
  l('Tudo Para Ele', 'Oswald Chambers', 'Devocionais', 'C1', 1, 1),
  l('O Refúgio Secreto', 'Corrie ten Boom', 'Biografias cristãs', 'C2', 1, 1),
  l('As Cinco Linguagens do Amor', 'Gary Chapman', 'Família e casamento', 'D1', 2, 1, {
    destaque: true, destaqueNota: 'Para o mês da família',
  }),
  l('O Significado do Casamento', 'Timothy Keller', 'Família e casamento', 'D1', 1, 0),
  l('A Bíblia em 365 Histórias', 'Mary Batchelor', 'Infantil', 'E1', 2, 2),
  l('O Leão, a Feiticeira e o Guarda-Roupa', 'C. S. Lewis', 'Juvenil', 'E2', 2, 1),
  l('Como Ler a Bíblia Livro por Livro', 'Gordon Fee e Douglas Stuart', 'Estudos bíblicos', 'F1', 1, 1),
  l('O Peregrino', 'John Bunyan', 'Ficção cristã', 'G1', 2, 1),
  l('Cartas de um Diabo a seu Aprendiz', 'C. S. Lewis', 'Ficção cristã', 'G1', 1, 1),
  l('Ben-Hur', 'Lew Wallace', 'Outros', 'G2', 1, 1),
];
