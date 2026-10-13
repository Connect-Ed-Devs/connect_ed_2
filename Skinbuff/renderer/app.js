/**
 * The Skinbuff controller.
 *
 * Holds the workspace state, keeps it in step with the event stream, and hands it to the
 * views. Deliberately thin: every view is a pure render of state, and every change to
 * state goes through `applyEvent` from the shared engine — the same reducer the server
 * uses, so "what a workspace is" has one definition rather than two.
 *
 * Optimistic and idempotent where it matters: a message the user sends is rendered
 * immediately under an id the client chooses, the server echoes that same id back on the
 * stream, and the reducer ignores the echo. That way the message appears without waiting
 * for a round trip and still appears exactly once.
 */

import { COLUMNS, COLUMN_LABELS, applyEvent, classifyEvent, deriveStats, normalizeSnapshot } from '/src/state/board.mjs';
import { renderApprovals } from '/views/approvals.js';
import { renderBoard } from '/views/board.js';
import { renderChat } from '/views/chat.js';
import { renderTeam } from '/views/team.js';
import { clear, el } from '/dom.js';

/** @param {string} id */
function must(id) {
  const node = document.getElementById(id);
  if (!node) throw new Error(`Skinbuff: #${id} is missing from the document`);
  return node;
}

const dom = {
  badge: must('mode-badge'),
  statTasks: must('stat-tasks'),
  statAgents: must('stat-agents'),
  statApprovals: must('stat-approvals'),
  facts: must('rail-facts'),
  legend: must('rail-legend'),
  chat: must('chat'),
  board: must('panel-board'),
  team: must('panel-team'),
  approvals: must('panel-approvals'),
  tabs: must('tabs'),
  status: must('status'),
  composer: /** @type {HTMLFormElement} */ (must('composer')),
  prompt: /** @type {HTMLTextAreaElement} */ (must('prompt')),
};

const PANEL_LABEL = { board: 'Board', team: 'Team', approvals: 'Approvals' };

let state = normalizeSnapshot({}, 'demo');
const ui = { panel: /** @type {'board' | 'team' | 'approvals'} */ ('board'), busy: false };
let localCounter = 0;

/** @param {string} text @param {'info' | 'error'} [tone] */
function setStatus(text, tone = 'info') {
  dom.status.textContent = text;
  dom.status.dataset.tone = tone;
}

/** @param {unknown} value */
function safeParse(value) {
  if (typeof value !== 'string' || !value) return null;
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

function renderChrome() {
  dom.badge.textContent = state.mode === 'live' ? 'live' : 'demo data';
  dom.badge.dataset.mode = state.mode;

  const stats = deriveStats(state);
  dom.statTasks.textContent = `${stats.openTasks} open`;
  dom.statAgents.textContent = `${stats.agents.working} working / ${state.agents.length}`;
  dom.statApprovals.textContent = `${stats.pendingApprovals} to review`;

  clear(dom.facts);
  for (const [label, value] of [
    ['name', state.workspace.name || '—'],
    ['project', state.workspace.project || '—'],
    ['branch', state.workspace.branch || '—'],
    ['lead', state.lead.name + (state.lead.model ? ` · ${state.lead.model}` : '')],
  ]) {
    dom.facts.append(el('dt', undefined, label), el('dd', undefined, value));
  }

  clear(dom.legend);
  for (const column of COLUMNS) {
    const item = el('li');
    const dot = el('span', 'legend__dot');
    dot.dataset.column = column;
    const count = el('span', 'legend__count', String(stats.columns[column]));
    item.append(dot, el('span', undefined, COLUMN_LABELS[column]), count);
    dom.legend.append(item);
  }

  for (const [panel, count] of [
    ['board', state.tasks.length],
    ['team', state.agents.length],
    ['approvals', stats.pendingApprovals],
  ]) {
    const node = document.getElementById(`tab-count-${panel}`);
    if (node) node.textContent = String(count);
    const tab = dom.tabs.querySelector(`[data-panel="${panel}"]`);
    if (tab) {
      tab.classList.toggle('is-active', ui.panel === panel);
      tab.setAttribute('aria-selected', ui.panel === panel ? 'true' : 'false');
    }
  }
}

function render() {
  const now = Date.now();
  renderChrome();

  renderChat(dom.chat, state, { now });

  for (const [panel, root] of /** @type {[string, HTMLElement][]} */ ([
    ['board', dom.board],
    ['team', dom.team],
    ['approvals', dom.approvals],
  ])) {
    root.hidden = ui.panel !== panel;
  }

  renderBoard(dom.board, state, { now });
  renderTeam(dom.team, state, { now });
  renderApprovals(dom.approvals, state, {
    busy: ui.busy,
    decide: (id, decision) => void decide(id, decision),
  });
}

/** @param {string} text */
async function send(text) {
  const trimmed = text.trim();
  if (!trimmed) return;

  // Unique per message, not just per page load. The server journals whatever id this
  // carries and `/state` replays that journal, so a counter that restarted at 1 after a
  // reload would collide with an already-journaled id — and the reducer, which dedupes by
  // id, would silently drop the new turn from the conversation.
  const id = `local-${Date.now().toString(36)}-${(localCounter += 1)}`;
  // Show it now; the server echoes this same id, and the reducer ignores the echo.
  state = applyEvent(state, { type: 'message', message: { id, role: 'user', text: trimmed } });
  ui.busy = true;
  render();

  try {
    const response = await fetch('/api/skinbuff/chat', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ text: trimmed, id }),
    });
    const payload = await response.json().catch(() => null);
    if (!response.ok) {
      // A refused send is reported as refused, and no reply is invented for it.
      setStatus(`Send failed: ${payload && payload.error ? payload.error : `HTTP ${response.status}`}`, 'error');
    } else if (payload && payload.error) {
      // The turn reached Freebuff but the agent reported a problem. Saying so beats a
      // cheerful "sent" over a reply that came back broken.
      setStatus(`Freebuff reported: ${payload.error}`, 'error');
    } else if (payload && payload.mode === 'live') {
      setStatus('Sent to Freebuff. The Lead\u2019s reply is in the conversation.');
    } else {
      setStatus('Sent to the demo Lead. Run `npm run attach` to reach the real agent.');
    }
  } catch (error) {
    setStatus(`Send failed: ${error instanceof Error ? error.message : String(error)}`, 'error');
  } finally {
    ui.busy = false;
    render();
  }
}

/**
 * @param {string} id
 * @param {'allow' | 'deny'} decision
 */
async function decide(id, decision) {
  // Not applied optimistically. When a real invitation is behind this, the decision is a
  // write to Freebuff that can be refused, and marking it resolved before the server (and
  // therefore the app) agrees would show the user an approval that never happened.
  const approval = state.approvals.find((entry) => entry.id === id);
  ui.busy = true;
  render();
  try {
    const response = await fetch(`/api/skinbuff/approvals/${encodeURIComponent(id)}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        decision,
        // The identity of the invitation, when this one is real. The server falls back to
        // the workspace when these are absent.
        ...(approval?.invitationId ? { invitationId: approval.invitationId } : {}),
        ...(approval?.threadId ? { threadId: approval.threadId } : {}),
        ...(approval?.token ? { token: approval.token } : {}),
      }),
    });
    const payload = await response.json().catch(() => null);
    if (!response.ok) {
      setStatus(`Decision failed: ${payload && payload.error ? payload.error : `HTTP ${response.status}`}`, 'error');
      return;
    }
    state = applyEvent(state, { type: 'approval.resolved', approval: { id, decision } });
    setStatus(
      payload && payload.mode === 'live'
        ? `Sent to Freebuff: ${decision === 'deny' ? 'declined' : 'approved'}.`
        : payload && payload.detail
          ? payload.detail
          : `Recorded: ${decision}.`,
    );
  } catch (error) {
    setStatus(`Decision failed: ${error instanceof Error ? error.message : String(error)}`, 'error');
  } finally {
    ui.busy = false;
    render();
  }
}

/** Re-read the snapshot, e.g. after the stream reconnects and may have missed frames. */
async function refreshState() {
  try {
    const response = await fetch('/api/skinbuff/state', { headers: { accept: 'application/json' } });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const snapshot = await response.json();
    state = normalizeSnapshot(snapshot, snapshot && snapshot.mode === 'live' ? 'live' : 'demo');
    render();
  } catch (error) {
    setStatus(`Could not read the workspace: ${error instanceof Error ? error.message : String(error)}`, 'error');
  }
}

function connect() {
  const stream = new EventSource('/api/skinbuff/events');

  stream.addEventListener('skin.mode', (event) => {
    const data = safeParse(/** @type {MessageEvent} */ (event).data);
    if (data && (data.mode === 'live' || data.mode === 'demo')) {
      state.mode = data.mode;
      renderChrome();
    }
  });

  stream.addEventListener('skin.event', (event) => {
    const parsed = safeParse(/** @type {MessageEvent} */ (event).data);
    if (!parsed) return;
    const classified = classifyEvent(parsed);
    // Unrecognised frames are the expected case for orchestrator traffic whose shape is
    // not pinned; they are ignored rather than logged for every frame.
    if (!classified) return;
    state = applyEvent(state, classified);
    render();
  });

  stream.addEventListener('skin.error', (event) => {
    const data = safeParse(/** @type {MessageEvent} */ (event).data);
    setStatus(`Stream: ${data && data.error ? data.error : 'stopped'}`, 'error');
  });

  stream.addEventListener('open', () => {
    setStatus('Stream connected.');
    void refreshState();
  });

  stream.addEventListener('error', () => {
    setStatus('Stream disconnected — reconnecting…', 'error');
  });
}

dom.tabs.addEventListener('click', (event) => {
  const target = /** @type {HTMLElement | null} */ (event.target);
  const button = target?.closest('[data-panel]');
  if (!(button instanceof HTMLElement)) return;
  const panel = button.dataset.panel;
  if (panel !== 'board' && panel !== 'team' && panel !== 'approvals') return;
  ui.panel = panel;
  render();
  setStatus(`${PANEL_LABEL[panel]} shown.`);
});

dom.composer.addEventListener('submit', (event) => {
  event.preventDefault();
  const text = dom.prompt.value;
  dom.prompt.value = '';
  void send(text);
});

dom.prompt.addEventListener('keydown', (event) => {
  if (event.key === 'Enter' && !event.shiftKey) {
    event.preventDefault();
    dom.composer.requestSubmit();
  }
});

// Ages are rendered relative to now, so refresh them periodically without a stream event.
setInterval(render, 30_000);

render();
connect();
void refreshState();
setStatus('Skinbuff loaded.');
