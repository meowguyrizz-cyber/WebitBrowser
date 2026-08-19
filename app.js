const addressInput = document.getElementById('addressInput');
const goBtn = document.getElementById('goBtn');
const backBtn = document.getElementById('backBtn');
const forwardBtn = document.getElementById('forwardBtn');
const reloadBtn = document.getElementById('reloadBtn');
const statusPill = document.getElementById('statusPill');
const engineSelect = document.getElementById('engineSelect');
const welcomeForm = document.getElementById('welcomeForm');
const welcomeInput = document.getElementById('welcomeInput');

const searchEngines = {
  google: 'https://www.google.com/search?q=',
  duckduckgo: 'https://duckduckgo.com/?q=',
  bing: 'https://www.bing.com/search?q='
};

function isLikelyURL(value) {
  const trimmed = value.trim();
  if (!trimmed) return false;
  return /^https?:\/\//i.test(trimmed) || /^www\./i.test(trimmed) || /^[a-z0-9.-]+\.[a-z]{2,}/i.test(trimmed);
}

function normalizeTarget(rawValue) {
  const value = rawValue.trim();
  if (!value) return 'https://www.google.com';
  if (/^https?:\/\//i.test(value)) return value;
  if (/^www\./i.test(value)) return `https://${value}`;
  if (isLikelyURL(value)) return `https://${value}`;

  const engine = searchEngines[engineSelect.value] || searchEngines.google;
  return `${engine}${encodeURIComponent(value)}`;
}

function navigate(rawValue) {
  const target = normalizeTarget(rawValue);
  addressInput.value = target;
  window.open(target, '_blank', 'noopener,noreferrer');
  setDefenderStatus(true);
}

function checkUnsafe(value) {
  const lower = value.toLowerCase();
  const dangerousPatterns = ['javascript:', 'data:', 'file:', '.exe', '.apk', '.msi', '.dmg', '.bat', '.cmd', '.scr', '.jar'];
  return dangerousPatterns.some(pattern => lower.includes(pattern));
}

function setDefenderStatus(isSafe) {
  statusPill.textContent = isSafe ? 'WebDefender: Protected' : 'WebDefender: Blocked';
  statusPill.classList.toggle('blocked', !isSafe);
}

function safeNavigation() {
  const rawValue = addressInput.value;
  if (!rawValue.trim()) {
    navigate('https://www.google.com');
    return;
  }

  const target = normalizeTarget(rawValue);
  if (checkUnsafe(target)) {
    setDefenderStatus(false);
    return;
  }

  navigate(target);
}

goBtn.addEventListener('click', safeNavigation);
addressInput.addEventListener('keydown', (event) => {
  if (event.key === 'Enter') safeNavigation();
});

backBtn.addEventListener('click', () => {
  window.history.back();
});

forwardBtn.addEventListener('click', () => {
  window.history.forward();
});

reloadBtn.addEventListener('click', () => {
  window.location.reload();
});

welcomeForm.addEventListener('submit', (event) => {
  event.preventDefault();
  addressInput.value = welcomeInput.value;
  safeNavigation();
});

setDefenderStatus(true);
