// ============================================================================
// GitLens4D - pintura de diff, compartilhada pela tela de Diff e pela de
// Histórico. Injetada pelo host no lugar do marcador /*GITLENS_DIFF_JS*/
// (ver TGitWebHost.InjectBaseCss) -- duas cópias divergiriam no primeiro
// ajuste de cor.
//
// Trident/IE11: nada de arrow function, const/let, template literal ou
// Array.from aqui dentro.
// ============================================================================

function diffEscapeHtml(s) {
  return String(s === null || s === undefined ? '' : s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// Classifica pela primeira coluna, na ordem que o git usa. '+++'/'---' vêm
// ANTES de '+'/'-' porque são cabeçalho de arquivo, não conteúdo.
function diffLineClass(line) {
  if (line.indexOf('+++') === 0 || line.indexOf('---') === 0) { return 'dl-file'; }
  if (line.indexOf('@@') === 0) { return 'dl-hunk'; }
  if (line.charAt(0) === '+') { return 'dl-add'; }
  if (line.charAt(0) === '-') { return 'dl-del'; }
  if (line.indexOf('diff --git') === 0 || line.indexOf('index ') === 0 ||
      line.indexOf('new file mode') === 0 || line.indexOf('deleted file mode') === 0 ||
      line.indexOf('similarity index') === 0 || line.indexOf('rename ') === 0) {
    return 'dl-meta';
  }
  return '';
}

// Numera pelo arquivo NOVO: é o número que casa com o editor aberto na IDE.
// Linha removida não existe no arquivo novo, então fica sem número.
// Devolve {adds, dels} para quem quiser mostrar o resumo.
function renderDiffInto(target, text) {
  var lines = String(text === null || text === undefined ? '' : text).split(/\r\n|\r|\n/);
  var html = [];
  var lineNo = 0;
  var adds = 0;
  var dels = 0;
  var i, line, cls, label, m;

  for (i = 0; i < lines.length; i++) {
    line = lines[i];
    cls = diffLineClass(line);

    if (cls === 'dl-hunk') {
      // @@ -12,7 +34,9 @@  ->  a numeração do lado novo recomeça em 34
      m = /\+(\d+)/.exec(line);
      lineNo = m ? (parseInt(m[1], 10) - 1) : lineNo;
      label = '';
    } else if (cls === 'dl-del') {
      dels++;
      label = '';
    } else if (cls === 'dl-add') {
      adds++;
      lineNo++;
      label = String(lineNo);
    } else if (cls === 'dl-file' || cls === 'dl-meta') {
      label = '';
    } else {
      lineNo++;
      label = String(lineNo);
    }

    html.push('<div class="dl ' + cls + '"><span class="no">' + label + '</span>' +
              diffEscapeHtml(line === '' ? ' ' : line) + '</div>');
  }

  target.innerHTML = html.join('');
  return { adds: adds, dels: dels };
}

function diffStatHtml(stat) {
  return '<span class="add">+' + stat.adds + '</span> ' +
         '<span class="del">-' + stat.dels + '</span>';
}
