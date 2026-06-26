const API_BASE = window.location.origin;
let token = localStorage.getItem('wrc_token') || '';

const $ = (id) => document.getElementById(id);
const $$ = (sel) => document.querySelectorAll(sel);

async function api(method, path, body = null, auth = true) {
    const headers = { 'Content-Type': 'application/json' };
    if (auth && token) headers['Authorization'] = 'Bearer ' + token;
    const opts = { method, headers };
    if (body) opts.body = JSON.stringify(body);
    const res = await fetch(API_BASE + path, opts);
    const text = await res.text();
    try { return { status: res.status, data: JSON.parse(text) }; }
    catch { return { status: res.status, data: { success: false, error: text } }; }
}

function showLogin() {
    $('login').classList.remove('hidden');
    $('app').classList.add('hidden');
}

function showApp() {
    $('login').classList.add('hidden');
    $('app').classList.remove('hidden');
    loadStatus();
    loadCommands();
    loadConfig();
    loadWhitelist();
    loadBanlist();
}

$('login-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const password = $('password').value;
    const res = await api('POST', '/api/login', { username: 'admin', password }, false);
    if (res.data.success && res.data.token) {
        token = res.data.token;
        localStorage.setItem('wrc_token', token);
        $('login-error').textContent = '';
        showApp();
    } else {
        $('login-error').textContent = res.data.error || 'Login failed';
    }
});

$('logout-link').addEventListener('click', async (e) => {
    e.preventDefault();
    await api('POST', '/api/logout', {});
    token = '';
    localStorage.removeItem('wrc_token');
    showLogin();
});

$$('nav a[data-tab]').forEach(link => {
    link.addEventListener('click', (e) => {
        e.preventDefault();
        const tab = link.dataset.tab;
        $$('nav a[data-tab]').forEach(l => l.classList.remove('active'));
        link.classList.add('active');
        $$('.tab').forEach(t => t.classList.remove('active'));
        $('tab-' + tab).classList.add('active');
    });
});

async function loadStatus() {
    const health = await api('GET', '/api/health', null, false);
    $('health-status').textContent = health.data.status === 'ok' ? 'Online' : 'Offline';
    $('health-status').style.color = health.data.status === 'ok' ? 'var(--success)' : 'var(--error)';

    const players = await api('GET', '/api/players');
    $('players-list').textContent = players.data.success ? players.data.message : players.data.error || 'Could not load';
}

async function loadCommands() {
    const res = await api('GET', '/api/commands');
    if (!res.data.success) return;
    const list = $('commands-list');
    list.innerHTML = '';
    for (const name in res.data.commands) {
        const cmd = res.data.commands[name];
        const div = document.createElement('div');
        div.textContent = name + (cmd.args && cmd.args.length ? ' ' + cmd.args.join(' ') : '') + ' — ' + cmd.description;
        list.appendChild(div);
    }
}

async function runCommand() {
    const input = $('console-input');
    const command = input.value.trim();
    if (!command) return;
    input.value = '';
    appendConsole('> ' + command, 'cmd');
    const res = await api('POST', '/api/command', { command });
    const cls = res.data.success ? 'res' : 'err';
    appendConsole(res.data.message || res.data.error || 'No response', cls);
}

function appendConsole(text, cls) {
    const out = $('console-output');
    const entry = document.createElement('div');
    entry.className = 'entry ' + cls;
    entry.textContent = text;
    out.appendChild(entry);
    out.scrollTop = out.scrollHeight;
}

$('console-send').addEventListener('click', runCommand);
$('console-input').addEventListener('keydown', (e) => { if (e.key === 'Enter') runCommand(); });

async function loadConfig() {
    const res = await api('GET', '/api/config');
    if (!res.data.success) return;
    const cfg = res.data.config;
    $('cfg-discord-webhook').value = cfg.discord && cfg.discord.webhook_url || '';
    $('cfg-http-port').value = cfg.http && cfg.http.port || 8780;
    $('cfg-log-level').value = cfg.general && cfg.general.log_level || 'info';
}

$('cfg-save').addEventListener('click', async () => {
    const payload = {
        admin_password: $('cfg-admin-password').value || null,
        rcon_password: $('cfg-rcon-password').value || null,
        discord_webhook_url: $('cfg-discord-webhook').value,
        http_port: parseInt($('cfg-http-port').value, 10) || 8780,
        log_level: $('cfg-log-level').value,
    };
    const res = await api('POST', '/api/config', payload);
    $('cfg-message').textContent = res.data.success ? 'Saved.' : (res.data.error || 'Failed');
    $('cfg-message').style.color = res.data.success ? 'var(--success)' : 'var(--error)';
});

let whitelist = { steam_ids: [], ip_whitelist: [] };

async function loadWhitelist() {
    const res = await api('GET', '/api/whitelist');
    if (!res.data.success) return;
    whitelist = res.data.whitelist;
    renderList('wl-steam-list', whitelist.steam_ids || [], removeSteamId);
    renderList('wl-ip-list', whitelist.ip_whitelist || [], removeIp);
}

function renderList(listId, items, removeFn) {
    const list = $(listId);
    list.innerHTML = '';
    items.forEach(item => {
        const li = document.createElement('li');
        li.textContent = item;
        const btn = document.createElement('button');
        btn.textContent = 'Remove';
        btn.addEventListener('click', () => removeFn(item));
        li.appendChild(btn);
        list.appendChild(li);
    });
}

function removeSteamId(id) {
    whitelist.steam_ids = whitelist.steam_ids.filter(x => x !== id);
    renderList('wl-steam-list', whitelist.steam_ids, removeSteamId);
}
function removeIp(ip) {
    whitelist.ip_whitelist = whitelist.ip_whitelist.filter(x => x !== ip);
    renderList('wl-ip-list', whitelist.ip_whitelist, removeIp);
}

$('wl-steam-add').addEventListener('click', () => {
    const val = $('wl-steam-input').value.trim();
    if (!val) return;
    whitelist.steam_ids = whitelist.steam_ids || [];
    if (!whitelist.steam_ids.includes(val)) whitelist.steam_ids.push(val);
    $('wl-steam-input').value = '';
    renderList('wl-steam-list', whitelist.steam_ids, removeSteamId);
});
$('wl-ip-add').addEventListener('click', () => {
    const val = $('wl-ip-input').value.trim();
    if (!val) return;
    whitelist.ip_whitelist = whitelist.ip_whitelist || [];
    if (!whitelist.ip_whitelist.includes(val)) whitelist.ip_whitelist.push(val);
    $('wl-ip-input').value = '';
    renderList('wl-ip-list', whitelist.ip_whitelist, removeIp);
});
$('wl-save').addEventListener('click', async () => {
    const res = await api('POST', '/api/whitelist', whitelist);
    $('wl-message').textContent = res.data.success ? 'Saved.' : (res.data.error || 'Failed');
    $('wl-message').style.color = res.data.success ? 'var(--success)' : 'var(--error)';
});

let banlist = [];

async function loadBanlist() {
    const res = await api('GET', '/api/banlist');
    if (!res.data.success) return;
    banlist = res.data.banlist || [];
    renderBanlist();
}

function renderBanlist() {
    const tbody = $('ban-list');
    tbody.innerHTML = '';
    banlist.forEach((entry, idx) => {
        const tr = document.createElement('tr');
        const tdUser = document.createElement('td');
        tdUser.textContent = entry.userid;
        const tdReason = document.createElement('td');
        tdReason.textContent = entry.reason || '';
        const tdAction = document.createElement('td');
        const btn = document.createElement('button');
        btn.textContent = 'Unban';
        btn.addEventListener('click', () => unban(idx));
        tdAction.appendChild(btn);
        tr.appendChild(tdUser);
        tr.appendChild(tdReason);
        tr.appendChild(tdAction);
        tbody.appendChild(tr);
    });
}

function unban(idx) {
    banlist.splice(idx, 1);
    renderBanlist();
}

$('ban-add').addEventListener('click', async () => {
    const userid = $('ban-userid').value.trim();
    const reason = $('ban-reason').value.trim();
    if (!userid) return;
    const res = await api('POST', '/api/banlist', { userid, reason, action: 'ban' });
    $('ban-message').textContent = res.data.success ? 'Banned.' : (res.data.error || 'Failed');
    $('ban-message').style.color = res.data.success ? 'var(--success)' : 'var(--error)';
    if (res.data.success) {
        $('ban-userid').value = '';
        $('ban-reason').value = '';
        loadBanlist();
    }
});

if (token) showApp(); else showLogin();
