const preview = document.querySelector('#project-preview');
const host = document.querySelector('.preview-host');
const dialog = document.querySelector('#preview-dialog');
const selectors = [...document.querySelectorAll('.project-select')];
const mobile = window.matchMedia('(max-width: 980px)');
const icon = document.querySelector('#preview-icon');
const image = document.querySelector('#preview-image');
const media = document.querySelector('#preview-media');
const link = document.querySelector('#preview-link');
const status = document.querySelector('#preview-status');

function selectProject(button) {
  const row = button.closest('.project-row');
  const title = row.querySelector('.project-title').textContent;
  const sourceIcon = row.querySelector('.project-icon');
  const sourceLink = row.querySelector('.project-link');
  const generic = row.hasAttribute('data-generic-icon');

  for (const selector of selectors) selector.setAttribute('aria-pressed', String(selector === button));
  document.querySelector('#preview-title').textContent = title;
  document.querySelector('#preview-description').textContent = row.querySelector('.project-description').textContent;
  document.querySelector('#preview-platform').textContent = row.querySelector('.platform').textContent;
  icon.src = sourceIcon.src;
  icon.classList.toggle('generic-icon', generic);
  image.src = row.dataset.preview || sourceIcon.src;
  image.alt = row.dataset.preview ? `${title}の画面` : `${title}のアイコン`;
  image.classList.toggle('generic-icon', generic);
  media.className = `preview-media ${row.dataset.preview ? 'has-screen' : 'has-icon'}`;
  link.hidden = !sourceLink;
  status.hidden = Boolean(sourceLink);
  if (sourceLink) {
    link.href = sourceLink.href;
    document.querySelector('#preview-link-label').textContent = sourceLink.textContent.trim();
  } else {
    link.removeAttribute('href');
  }
  if (mobile.matches) dialog.showModal();
}

function placePreview() {
  if (dialog.open) dialog.close();
  (mobile.matches ? dialog : host).append(preview);
  for (const button of selectors) {
    if (mobile.matches) button.setAttribute('aria-haspopup', 'dialog');
    else button.removeAttribute('aria-haspopup');
  }
}

for (const button of selectors) button.addEventListener('click', () => selectProject(button));
mobile.addEventListener('change', placePreview);
placePreview();
