/**
 * The agent roster: who is on this workspace, what they are on, and the tail of what they
 * have been doing.
 *
 * The activity tail is capped per agent (see `normalizeActivity`) because it is a live log
 * tail, not an archive — an unbounded list would grow the DOM without bound for the
 * lifetime of a session.
 */

import { agentLabel, clear, el, emptyState, relativeTime } from '/dom.js';

/**
 * @param {HTMLElement} root
 * @param {import('/src/state/board.mjs').SkWorkspaceState} state
 * @param {{ now: number }} options
 */
export function renderTeam(root, state, options) {
  clear(root);

  if (state.agents.length === 0) {
    emptyState(
      root,
      'panel__empty',
      state.mode === 'live'
        ? 'Attached. No agent activity has arrived on the event stream yet.'
        : 'No agents in this workspace yet.',
    );
    return;
  }

  const roster = el('div', 'roster');
  roster.setAttribute('data-testid', 'roster');

  for (const agent of state.agents) {
    const card = el('article', 'agent');
    card.dataset.agentId = agent.id;
    card.dataset.status = agent.status;

    const head = el('div', 'agent__head');
    head.append(el('span', 'agent__name', agent.name));
    if (agent.role) head.append(el('span', 'agent__role', agent.role));
    const pill = el('span', 'pill', agent.status);
    pill.dataset.status = agent.status;
    head.append(pill);
    card.append(head);

    if (agent.task) card.append(el('p', 'agent__task', agent.task));
    if (agent.model) {
      const foot = el('div', 'card__foot');
      foot.append(el('span', 'chip', agent.model));
      card.append(foot);
    }

    if (agent.activity.length > 0) {
      const log = el('ul', 'log');
      for (const entry of agent.activity.slice(-3)) {
        const item = el('li');
        const age = relativeTime(entry.at, options.now);
        if (age) item.append(el('span', undefined, age));
        item.append(el('span', undefined, entry.text));
        log.append(item);
      }
      card.append(log);
    }

    roster.append(card);
  }

  root.append(roster);

  // Mention an unassigned task's owner id if the roster has never seen it, so a card is
  // never a mystery. Silent in the normal case.
  const orphan = state.tasks.find((task) => task.agent && !state.agents.some((a) => a.id === task.agent));
  if (orphan) {
    root.append(el('p', 'panel__empty', `Also referenced: ${agentLabel(state.agents, orphan.agent)}`));
  }
}
