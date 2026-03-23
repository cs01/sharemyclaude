"use strict";

const TERMPAIR_VERSION = "1.0.0";
const IV_LENGTH = 12;

const $ = (sel) => document.querySelector(sel);
const $id = (id) => document.getElementById(id);

// ---- Toast ----

let readOnlyToastShown = false;

function toast(msg, duration) {
  duration = duration || 5000;
  const container = $id("toast-container");
  const el = document.createElement("div");
  el.className = "toast";
  el.textContent = msg;
  container.appendChild(el);
  el.addEventListener("click", () => el.remove());
  setTimeout(() => el.remove(), duration);
}

// ---- Encryption (Web Crypto API, AES-128-GCM) ----

async function importAesKey(rawKeyData, usages) {
  return crypto.subtle.importKey(
    "raw",
    rawKeyData,
    { name: "AES-GCM" },
    false,
    usages
  );
}

function ivFromInteger(count) {
  const iv = new Uint8Array(IV_LENGTH);
  for (let i = IV_LENGTH - 1; i >= 0 && count > 0; i--) {
    iv[i] = count % 256;
    count = Math.floor(count / 256);
  }
  return iv;
}

async function aesDecrypt(cryptoKey, encryptedPayload) {
  const iv = encryptedPayload.slice(0, IV_LENGTH);
  const ciphertext = encryptedPayload.slice(IV_LENGTH);
  const plaintext = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv },
    cryptoKey,
    ciphertext
  );
  return new Uint8Array(plaintext);
}

async function aesEncrypt(cryptoKey, utf8String, ivCount) {
  const iv = ivFromInteger(ivCount);
  const encoded = new TextEncoder().encode(utf8String);
  const encrypted = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    cryptoKey,
    encoded
  );
  const combined = new Uint8Array(iv.byteLength + encrypted.byteLength);
  combined.set(iv, 0);
  combined.set(new Uint8Array(encrypted), iv.byteLength);
  return btoa(String.fromCharCode(...combined));
}

function base64ToBytes(b64) {
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

function base64urlToBytes(b64url) {
  let b64 = b64url.replace(/-/g, "+").replace(/_/g, "/");
  while (b64.length % 4) b64 += "=";
  return base64ToBytes(b64);
}

function bytesToBase64(bytes) {
  let bin = "";
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin);
}

// ---- State ----

const state = {
  ws: null,
  xterm: null,
  aesKeys: { unix: null, browser: null, ivCount: null, maxIvCount: null },
  terminalData: null,
  terminalId: null,
  bootstrapKeyB64: null,
  status: null,
  isPublic: false,
  sessionPollId: null,
  durationIntervalId: null,
  connectedAt: null,
};

// ---- URL parsing ----

function getParams() {
  const pathMatch = window.location.pathname.match(/\/s\/([^/]+)/);
  const terminalId = pathMatch
    ? pathMatch[1]
    : new URLSearchParams(window.location.search).get("terminal_id");
  const hash = window.location.hash;
  const bootstrapKeyB64 = hash ? hash.substring(1) : null;
  return { terminalId, bootstrapKeyB64 };
}

function getServerBaseUrl() {
  const path = window.location.pathname.replace(/\/s\/.*$/, "/");
  return `${window.location.protocol}//${window.location.host}${path}`;
}

function httpToWs(url) {
  return url.replace(/^http/, "ws");
}

// ---- UI updates ----

function setStatus(status) {
  state.status = status;
  const bar = $id("status-bar");
  const text = $id("status-text");

  if (!status) {
    bar.style.display = "none";
    return;
  }

  bar.style.display = "flex";
  text.textContent = status;

  bar.className = status === "Connected" ? "connected" : "disconnected";
}

function updateBottomBar() {
  const access = $id("access-mode");
  if (state.terminalData) {
    access.textContent = state.terminalData.allow_browser_control ? "read/write" : "read-only";
  }
}

function loadXtermAssets() {
  return new Promise((resolve) => {
    if (window.Terminal) { resolve(); return; }
    const link = document.createElement("link");
    link.rel = "stylesheet";
    link.href = "xterm.min.css";
    document.head.appendChild(link);
    const script = document.createElement("script");
    script.src = "xterm.min.js";
    script.onload = resolve;
    document.body.appendChild(script);
  });
}

function showTerminal() {
  $id("landing").style.display = "none";
  $id("terminal-view").style.display = "flex";
  $id("status-bar").style.display = "flex";
  $id("back-btn").style.display = "inline-flex";
  $id("footer-links").style.display = "none";
  if (state.sessionPollId) {
    clearInterval(state.sessionPollId);
    state.sessionPollId = null;
  }
}

function disconnectAndGoBack() {
  if (state.ws) {
    state.ws.close();
    state.ws = null;
  }
  if (state.xterm) {
    state.xterm.dispose();
    state.xterm = null;
  }
  if (state.durationIntervalId) {
    clearInterval(state.durationIntervalId);
    state.durationIntervalId = null;
  }
  state.terminalData = null;
  state.terminalId = null;
  state.isPublic = false;
  state.connectedAt = null;
  state.aesKeys = { unix: null, browser: null, ivCount: null, maxIvCount: null };
  readOnlyToastShown = false;

  $id("terminal-view").style.display = "none";
  $id("terminal").innerHTML = "";
  $id("landing").style.display = "block";
  $id("status-bar").style.display = "none";
  $id("back-btn").style.display = "none";
  $id("footer-links").style.display = "flex";
  $id("reconnect-btn").style.display = "none";
  $id("client-count").textContent = "";
  $id("session-duration").textContent = "";
  setStatus(null);

  history.pushState(null, "", "/");
  startSessionPolling();
}

// ---- Terminal setup ----

function createXterm() {
  const term = new Terminal({
    cursorBlink: true,
    macOptionIsMeta: true,
    scrollback: 5000,
    fontSize: 14,
    theme: {
      background: "#111111",
      foreground: "#e8e0d4",
      cursor: "#d4a574",
    },
  });
  return term;
}

// ---- WebSocket message handlers ----

async function handleMessage(data) {
  switch (data.event) {
    case "new_output":
      await handleNewOutput(data);
      break;
    case "resize":
      handleResize(data);
      break;
    case "num_clients":
      handleNumClients(data);
      break;
    case "aes_keys":
      await handleAesKeys(data);
      break;
    case "aes_key_rotation":
      await handleKeyRotation(data);
      break;
    case "error":
      toast("Error: " + (data.payload || "unknown"));
      break;
    default:
      console.warn("unknown event:", data.event);
  }
}

async function handleNewOutput(data) {
  if (state.isPublic) {
    try {
      const raw = base64ToBytes(data.payload);
      const json = JSON.parse(new TextDecoder().decode(raw));
      const ptyOutput = base64ToBytes(json.pty_output);
      state.xterm.write(ptyOutput);
    } catch (e) {
      console.error("public output error:", e);
    }
    return;
  }
  if (!state.aesKeys.unix) return;
  try {
    const encrypted = base64ToBytes(data.payload);
    const decrypted = await aesDecrypt(state.aesKeys.unix, encrypted);
    const json = JSON.parse(new TextDecoder().decode(decrypted));
    const ptyOutput = base64ToBytes(json.pty_output);
    state.xterm.write(ptyOutput);
  } catch (e) {
    console.error("decrypt error:", e);
  }
}

function handleResize(data) {
  if (data.payload && data.payload.cols != null && data.payload.rows != null) {
    const cols = data.payload.cols;
    const rows = data.payload.rows;
    if (cols > 0 && rows > 0) {
      state.xterm.resize(cols, rows);
    }
    $id("terminal-dimensions").textContent = `${cols}x${rows}`;
  }
}

function handleNumClients(data) {
  const n = data.payload;
  $id("client-count").textContent = n === 1 ? "1 viewer" : `${n} viewers`;
}

async function handleAesKeys(data) {
  try {
    const { terminalId, bootstrapKeyB64 } = getParams();
    const bootstrapKeyData = base64urlToBytes(bootstrapKeyB64);
    const bootstrapKey = await importAesKey(bootstrapKeyData, ["decrypt"]);

    const unixKeyEncrypted = base64ToBytes(data.payload.b64_bootstrap_unix_aes_key);
    const unixKeyRaw = await aesDecrypt(bootstrapKey, unixKeyEncrypted);
    state.aesKeys.unix = await importAesKey(unixKeyRaw, ["decrypt"]);

    const browserKeyEncrypted = base64ToBytes(data.payload.b64_bootstrap_browser_aes_key);
    const browserKeyRaw = await aesDecrypt(bootstrapKey, browserKeyEncrypted);
    state.aesKeys.browser = await importAesKey(browserKeyRaw, ["encrypt"]);

    state.aesKeys.ivCount = parseInt(data.payload.iv_count, 10);
    state.aesKeys.maxIvCount = parseInt(data.payload.max_iv_count, 10);
  } catch (e) {
    console.error("failed to obtain encryption keys:", e);
    toast("Failed to obtain encryption keys. Is your key valid?");
    setStatus("Key Error");
  }
}

async function handleKeyRotation(data) {
  if (!state.aesKeys.unix) return;
  try {
    const newUnixRaw = await aesDecrypt(
      state.aesKeys.unix,
      base64ToBytes(data.payload.b64_aes_secret_unix_key)
    );
    const newBrowserRaw = await aesDecrypt(
      state.aesKeys.unix,
      base64ToBytes(data.payload.b64_aes_secret_browser_key)
    );
    state.aesKeys.unix = await importAesKey(newUnixRaw, ["decrypt"]);
    state.aesKeys.browser = await importAesKey(newBrowserRaw, ["encrypt"]);
  } catch (e) {
    console.error("key rotation failed:", e);
    toast("AES key rotation failed");
  }
}

// ---- Input handling ----

function getSalt() {
  return bytesToBase64(crypto.getRandomValues(new Uint8Array(12)));
}

async function sendInput(input) {
  if (state.isPublic || !state.terminalData?.allow_browser_control) {
    if (!readOnlyToastShown) {
      toast("This session is read-only");
      readOnlyToastShown = true;
    }
    return;
  }
  if (!state.aesKeys.browser || state.aesKeys.ivCount == null) {
    toast("Cannot type: encryption keys not available");
    return;
  }

  const payload = JSON.stringify({ data: input, salt: getSalt() });
  const encrypted = await aesEncrypt(
    state.aesKeys.browser,
    payload,
    state.aesKeys.ivCount++
  );

  state.ws.send(JSON.stringify({ event: "command", payload: encrypted }));

  if (state.aesKeys.ivCount >= state.aesKeys.maxIvCount) {
    state.ws.send(JSON.stringify({ event: "request_key_rotation" }));
    state.aesKeys.maxIvCount += 1000;
  }
}

function setupKeyHandler(xterm) {
  xterm.attachCustomKeyEventHandler((e) => {
    if (e.type !== "keydown") return true;
    const mod = e.ctrlKey && e.shiftKey || e.metaKey;
    if (mod) {
      const key = e.key.toLowerCase();
      if (key === "v") {
        if (state.isPublic || !state.terminalData?.allow_browser_control) {
          if (!readOnlyToastShown) {
            toast("This session is read-only");
            readOnlyToastShown = true;
          }
          return false;
        }
        navigator.clipboard.readText().then((text) => sendInput(text));
        return false;
      }
      if (key === "c" || key === "x") {
        const sel = xterm.getSelection();
        if (sel) navigator.clipboard.writeText(sel);
        xterm.focus();
        return false;
      }
    }
    return true;
  });
}

function formatElapsed(ms) {
  const s = Math.floor(ms / 1000);
  if (s < 60) return `${s}s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m ${s % 60}s`;
  const h = Math.floor(m / 60);
  return `${h}h ${m % 60}m`;
}

function startDurationTimer() {
  state.connectedAt = Date.now();
  updateDuration();
  state.durationIntervalId = setInterval(updateDuration, 1000);
}

function updateDuration() {
  if (!state.connectedAt) return;
  $id("session-duration").textContent = formatElapsed(Date.now() - state.connectedAt);
}

// ---- Connection ----

async function connect(terminalId, bootstrapKeyB64) {
  const baseUrl = getServerBaseUrl();

  const resp = await fetch(`${baseUrl}terminal/${terminalId}`);
  if (resp.status !== 200) {
    toast("Session not found. Check the ID.");
    setStatus("Not Found");
    return;
  }

  state.terminalData = await resp.json();
  state.isPublic = state.terminalData.is_public || false;
  state.terminalId = terminalId;
  state.bootstrapKeyB64 = bootstrapKeyB64;

  if (!state.isPublic && !bootstrapKeyB64) {
    toast("Missing encryption key — check your link");
    return;
  }

  await loadXtermAssets();
  showTerminal();

  const xterm = createXterm();
  state.xterm = xterm;
  xterm.open($id("terminal"));

  setupKeyHandler(xterm);

  xterm.onData((data) => sendInput(data));

  const wsUrl = `${httpToWs(baseUrl)}connect_browser_to_terminal?terminal_id=${terminalId}`;
  const ws = new WebSocket(wsUrl);
  state.ws = ws;

  setStatus("Connecting...");

  ws.addEventListener("open", () => {
    setStatus("Connected");
    $id("reconnect-btn").style.display = "none";
    readOnlyToastShown = false;

    ws.send(JSON.stringify({ event: "request_terminal_dimensions" }));
    if (!state.isPublic) {
      ws.send(JSON.stringify({ event: "new_browser_connected", payload: {} }));
    }

    xterm.focus();
    updateBottomBar();
    $id("terminal-dimensions").textContent = `${xterm.cols}x${xterm.rows}`;
    startDurationTimer();
  });

  ws.addEventListener("message", async (event) => {
    try {
      const data = JSON.parse(event.data);
      await handleMessage(data);
    } catch (e) {
      console.error("failed to parse message:", e);
    }
  });

  ws.addEventListener("close", () => {
    setStatus("Disconnected");
    if (state.durationIntervalId) {
      clearInterval(state.durationIntervalId);
      state.durationIntervalId = null;
    }
    xterm.writeln("");
    xterm.writeln("\x1b[1;31mSession has ended\x1b[0m");
    $id("client-count").textContent = "";
    $id("reconnect-btn").style.display = "inline-flex";
  });

  ws.addEventListener("error", (event) => {
    console.error("websocket error:", event);
    toast("WebSocket connection error");
    setStatus("Error");
  });
}

function reconnect() {
  if (!state.terminalId) return;
  if (state.xterm) {
    state.xterm.dispose();
    state.xterm = null;
  }
  $id("terminal").innerHTML = "";
  $id("reconnect-btn").style.display = "none";
  connect(state.terminalId, state.bootstrapKeyB64);
}

// ---- Live Sessions ----

async function fetchSessions() {
  const container = $id("live-sessions");
  if (!container) return;

  try {
    const baseUrl = getServerBaseUrl();
    const resp = await fetch(`${baseUrl}api/sessions`);
    if (!resp.ok) return;
    const sessions = await resp.json();

    if (sessions.length === 0) {
      container.innerHTML = '<p class="no-sessions">No live sessions right now. Be the first to share one!</p>';
      $id("live-count").textContent = "";
      return;
    }

    $id("live-count").textContent = `(${sessions.length})`;

    container.innerHTML = sessions.map((s) => {
      const started = new Date(s.broadcast_start_time_iso);
      const elapsed = formatElapsed(Date.now() - started.getTime());
      const viewers = s.viewer_count === 1 ? "1 viewer" : `${s.viewer_count} viewers`;
      const safeId = encodeURIComponent(s.terminal_id);
      return `<a href="${baseUrl}s/${safeId}" class="session-card">
        <div class="session-name">${escapeHtml(s.display_name)}</div>
        <div class="session-meta">
          <span>${escapeHtml(s.command)}</span>
          <span>${viewers}</span>
          <span>${elapsed}</span>
        </div>
      </a>`;
    }).join("");
  } catch (e) {
    console.error("failed to fetch sessions:", e);
    if (state.sessionPollId) {
      clearInterval(state.sessionPollId);
      state.sessionPollId = null;
    }
    container.innerHTML = '<p class="no-sessions">Could not load sessions. Refresh to retry.</p>';
  }
}

function escapeHtml(s) {
  const div = document.createElement("div");
  div.textContent = s;
  return div.innerHTML;
}

function startSessionPolling() {
  fetchSessions();
  state.sessionPollId = setInterval(fetchSessions, 5000);
}

// ---- Init ----

function init() {
  $id("version").textContent = `v${TERMPAIR_VERSION}`;

  const baseUrl = getServerBaseUrl();
  const port = window.location.port || (window.location.protocol === "https:" ? "443" : "80");
  const host = `${window.location.protocol}//${window.location.hostname}`;
  $id("share-command").textContent = `sharemyclaude`;
  $id("share-command-public").textContent = `sharemyclaude --public`;

  if (!window.isSecureContext) {
    $id("secure-warning").style.display = "block";
  }

  $id("back-btn").addEventListener("click", (e) => {
    e.preventDefault();
    disconnectAndGoBack();
  });

  $id("reconnect-btn").addEventListener("click", (e) => {
    e.preventDefault();
    reconnect();
  });

  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && $id("terminal-view").style.display !== "none") {
      disconnectAndGoBack();
    }
  });

  const { terminalId, bootstrapKeyB64 } = getParams();

  if (terminalId) {
    $id("input-terminal-id").value = terminalId;
  }
  if (bootstrapKeyB64) {
    $id("input-secret-key").value = bootstrapKeyB64;
  }
  if (terminalId && bootstrapKeyB64) {
    connect(terminalId, bootstrapKeyB64);
  } else if (terminalId && !bootstrapKeyB64) {
    connect(terminalId, null);
  }

  $id("connect-form").addEventListener("submit", (e) => {
    e.preventDefault();
    const tid = $id("input-terminal-id").value.trim();
    const key = $id("input-secret-key").value.trim();
    if (!tid) { toast("Session ID cannot be empty"); return; }
    connect(tid, key || null);
  });

  document.querySelectorAll("#landing pre").forEach((pre) => {
    const btn = document.createElement("button");
    btn.className = "copy-btn";
    btn.textContent = "Copy";
    btn.addEventListener("click", () => {
      const code = pre.querySelector("code");
      navigator.clipboard.writeText(code ? code.textContent : pre.textContent);
      btn.textContent = "Copied!";
      setTimeout(() => { btn.textContent = "Copy"; }, 1500);
    });
    pre.appendChild(btn);
  });

  $id("copy-md-btn").addEventListener("click", () => {
    const md = [
      "# sharemyclaude",
      "",
      "Share your Claude Code session live in the browser at https://sharemyclau.de",
      "",
      "## Install",
      "",
      "```",
      "curl -fsSL https://raw.githubusercontent.com/cs01/sharemyclaude/main/install.sh | sh",
      "```",
      "",
      "## Share",
      "",
      "Public (listed on sharemyclau.de, read-only, no encryption):",
      "```",
      "sharemyclaude --public",
      "```",
      "",
      "Private (end-to-end encrypted):",
      "```",
      "sharemyclaude",
      "```",
      "",
      "Pass args to Claude after `--`:",
      "```",
      "sharemyclaude --public -- --dangerously-skip-permissions",
      "```",
      "",
      "- Website: https://sharemyclau.de",
      "- GitHub: https://github.com/cs01/sharemyclaude",
      "- Powered by: https://github.com/cs01/termpair",
    ].join("\n");
    navigator.clipboard.writeText(md);
    const btn = $id("copy-md-btn");
    btn.textContent = "Copied!";
    setTimeout(() => { btn.textContent = "Copy as Markdown"; }, 1500);
  });

  startSessionPolling();
}

document.addEventListener("DOMContentLoaded", init);
