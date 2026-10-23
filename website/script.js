/** Airlinerra static marketing-site interactions (no backend or account services). */
const menuButton = document.querySelector('#menu-toggle');
const nav = document.querySelector('#primary-nav');
const dialog = document.querySelector('#prelaunch-dialog');
const modalClose = document.querySelector('#close-modal');
const modalDone = document.querySelector('#modal-done');
const modalTitle = document.querySelector('#modal-title');
const modalDescription = document.querySelector('#modal-description');

function setMenu(open) {
  nav.classList.toggle('is-open', open);
  menuButton.setAttribute('aria-expanded', String(open));
  menuButton.setAttribute('aria-label', open ? 'Close navigation' : 'Open navigation');
  menuButton.innerHTML = open
    ? '<svg class="icon"><use href="#i-x"/></svg>'
    : '<svg class="icon"><use href="#i-menu"/></svg>';
}
menuButton.addEventListener('click', () => setMenu(!nav.classList.contains('is-open')));
nav.querySelectorAll('a').forEach(a => a.addEventListener('click', () => setMenu(false)));
document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') setMenu(false);
});
window.addEventListener('resize', () => {
  if (window.innerWidth > 860) setMenu(false);
});

const sections = [...document.querySelectorAll('main .section-anchor')];
const links = [...nav.querySelectorAll('a[href^="#"]')];
if ('IntersectionObserver' in window) {
  const observer = new IntersectionObserver(entries => {
    const visible = entries.filter(entry => entry.isIntersecting).sort((a, b) => b.intersectionRatio - a.intersectionRatio);
    if (!visible.length) return;
    const id = visible[0].target.id;
    links.forEach(a => a.classList.toggle('is-active', a.getAttribute('href') === `#${id}`));
  }, { rootMargin: '-22% 0px -61% 0px', threshold: [0, .15, .5] });
  sections.forEach(section => observer.observe(section));
}

function openInfo(kind) {
  if (kind === 'membership') {
    modalTitle.textContent = 'Membership details are coming.';
    modalDescription.textContent = 'Airlinerra will be paid-to-play after the seven-day trial. We have not finalized the price, billing options or membership terms yet. No payment is being collected on this template.';
  } else {
    modalTitle.textContent = 'Preparing for takeoff.';
    modalDescription.textContent = 'World 01 is planned as the first Airlinerra game world. Registration and the seven-day trial will become available only when the game and account system launch.';
  }
  if (typeof dialog.showModal === 'function') dialog.showModal();
  else dialog.setAttribute('open', '');
}
document.querySelectorAll('[data-action]').forEach(btn => btn.addEventListener('click', () => openInfo(btn.dataset.action)));
function closeInfo() { if (typeof dialog.close === 'function') dialog.close(); else dialog.removeAttribute('open'); }
modalClose.addEventListener('click', closeInfo);
modalDone.addEventListener('click', closeInfo);
dialog.addEventListener('click', event => { if (event.target === dialog) closeInfo(); });

const icon = (name) => `<svg class="icon" aria-hidden="true"><use href="#i-${name}"/></svg>`;
const tabContent = {
  routes: {
    eyebrow: 'ROUTE PLANNING', title: 'Design your network', subtitle: 'Every route connects markets, aircraft and schedules.',
    bars: [47, 79, 60, 90, 68, 100, 76, 87], labels: ['Airport connections', 'Schedule utilization', 'Competitive demand'],
    item: 'Plan the right routes for the aircraft you operate.', glyph: 'network', metric: 'ROUTES & TIMETABLES'
  },
  fleet: {
    eyebrow: 'FLEET CONTROL', title: 'Choose the right aircraft', subtitle: 'Build a fleet that matches your network and budget.',
    bars: [53, 68, 84, 59, 90, 73, 83, 94], labels: ['Aircraft types', 'Ownership & leasing', 'Fleet utilization'],
    item: 'Scale from your first aircraft to a global fleet.', glyph: 'plane', metric: 'AIRCRAFT & CAPACITY'
  },
  finance: {
    eyebrow: 'FINANCIAL OVERVIEW', title: 'Make every flight count', subtitle: 'Understand the economics behind your strategy.',
    bars: [44, 52, 49, 75, 63, 79, 87, 100], labels: ['Revenue & expenses', 'Investment planning', 'Operating efficiency'],
    item: 'Compare costs and performance as you expand.', glyph: 'chart', metric: 'FINANCE & PERFORMANCE'
  }
};
const tabPanel = document.querySelector('#preview-tab-content');
const tabs = [...document.querySelectorAll('[data-tab]')];
function renderTab(tab) {
  const data = tabContent[tab];
  if (!data) return;
  tabs.forEach(button => {
    const selected = button.dataset.tab === tab;
    button.classList.toggle('is-selected', selected);
    button.setAttribute('aria-selected', String(selected));
    button.tabIndex = selected ? 0 : -1;
  });
  tabPanel.innerHTML = `
    <div class="app-panel-title"><div><span class="tiny-label">${data.eyebrow}</span><h3>${data.title}</h3><p>${data.subtitle}</p></div><span class="app-illustration">${icon(data.glyph)}</span></div>
    <div class="app-chart"><div class="chart-grid"><span></span><span></span><span></span></div><div class="chart-bars">${data.bars.map((height, i) => `<i style="height:${height}%" class="bar-${i % 3}"></i>`).join('')}</div></div>
    <div class="app-legend"><span><i class="legend-orange"></i>${data.metric}</span><small>ILLUSTRATIVE TREND</small></div>
    <div class="app-list">${data.labels.map(label => `<span>${icon('check')}${label}</span>`).join('')}</div>
    <div class="app-hint">${icon('info')}${data.item}</div>`;
}
tabs.forEach(tab => {
  tab.addEventListener('click', () => renderTab(tab.dataset.tab));
  tab.addEventListener('keydown', (event) => {
    if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;
    event.preventDefault();
    let index = tabs.indexOf(tab);
    if (event.key === 'ArrowRight') index = (index + 1) % tabs.length;
    else if (event.key === 'ArrowLeft') index = (index + tabs.length - 1) % tabs.length;
    else if (event.key === 'Home') index = 0;
    else index = tabs.length - 1;
    renderTab(tabs[index].dataset.tab);
    tabs[index].focus();
  });
});
renderTab('routes');

const yearEl = document.querySelector('#copyright-year');
if (yearEl) yearEl.textContent = String(new Date().getFullYear());
