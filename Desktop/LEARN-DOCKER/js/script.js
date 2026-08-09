/* ============================================================
   DOCKER, DE CERO A PROFESIONAL — script compartido
   ============================================================ */

const NAV_ITEMS = [
  { id:'index',    code:'MAP-00', title:'Punto de partida',        file:'index.html' },
  { id:'instalacion', code:'INS-01', title:'Instalación y arquitectura', file:'01-instalacion.html' },
  { id:'comandos', code:'CMD-02', title:'Comandos esenciales',     file:'02-comandos-basicos.html' },
  { id:'imagenes', code:'IMG-03', title:'Imágenes y Dockerfile',   file:'03-imagenes-dockerfile.html' },
  { id:'volumenes',code:'VOL-04', title:'Volúmenes y redes',       file:'04-volumenes-redes.html' },
  { id:'compose',  code:'CMP-05', title:'Docker Compose',          file:'05-docker-compose.html' },
  { id:'produccion',code:'PRO-06', title:'Producción y referencia', file:'06-produccion-y-referencia.html' },
];

function renderChrome(currentId){
  const idx = NAV_ITEMS.findIndex(i => i.id === currentId);

  // ---- sidebar ----
  const sidebarRoot = document.getElementById('sidebar-root');
  if (sidebarRoot){
    const items = NAV_ITEMS.map((item, i) => {
      const isActive = item.id === currentId;
      const isDone = i < idx;
      return `
        <li class="sb-item">
          <a class="sb-link ${isActive ? 'active':''} ${isDone ? 'done':''}" href="${item.file}">
            <span class="sb-code">${item.code}</span>
            <span class="sb-title">${item.title}</span>
            <span class="sb-check">✓</span>
          </a>
        </li>`;
    }).join('');

    sidebarRoot.innerHTML = `
      <div class="sb-brand">
        <span class="mark">🐳 DOCKER<span class="dot">·</span>GUÍA</span>
        <span class="sub">De cero a profesional</span>
      </div>
      <ul class="sb-list">${items}</ul>
    `;
  }

  // ---- top progress rail ----
  const rail = document.getElementById('yard-rail');
  if (rail){
    rail.innerHTML = NAV_ITEMS.map((item, i) => {
      let cls = 'crate';
      if (i < idx) cls += ' done';
      if (i === idx) cls += ' current';
      return `<a class="${cls}" data-label="${item.code} · ${item.title}" href="${item.file}"></a>`;
    }).join('');
  }

  // ---- mobile toggle ----
  const toggle = document.getElementById('nav-toggle');
  if (toggle && sidebarRoot){
    toggle.addEventListener('click', () => sidebarRoot.classList.toggle('open'));
    document.addEventListener('click', (e) => {
      if (!sidebarRoot.contains(e.target) && e.target !== toggle && sidebarRoot.classList.contains('open')){
        sidebarRoot.classList.remove('open');
      }
    });
  }

  // ---- copy buttons ----
  document.querySelectorAll('.code-block').forEach(block => {
    const btn = block.querySelector('.copy-btn');
    const codeEl = block.querySelector('pre code, pre');
    if (!btn || !codeEl) return;
    btn.addEventListener('click', () => {
      const text = codeEl.innerText;
      navigator.clipboard.writeText(text).then(() => {
        const original = btn.textContent;
        btn.textContent = 'COPIADO ✓';
        btn.classList.add('copied');
        setTimeout(() => { btn.textContent = original; btn.classList.remove('copied'); }, 1600);
      });
    });
  });
}
