/**
 * The approvals queue — what needs a human before it happens.
 *
 * Pending first, resolved kept in place below: a decision that silently disappears is
 * indistinguishable from a decision that was never asked for. Ordering within each group
 * preserves the order the events arrived, because that is the order the agent asked.
 */

import { agentLabel, button, clear, el, emptyState } from '/dom.js';

/** @type {Record<string, string>} */
const RESOLVED_LABEL = { allowed: 'allowed', denied: 'denied', pending: '' };

/**
 * @param {HTMLElement} root
 * @param {import('/src/state/board.mjs').SkWorkspaceState} state
 * @param {{ decide: (id: string, decision: 'allow' | 'deny') => void, busy: boolean }} actions
 */
export function renderApprovals(root, state, actions) {
  clear(root);

  if (state.approvals.length === 0) {
    emptyState(
      root,
      'panel__empty',
      state.mode === 'live'
        ? 'Attached. Nothing is waiting on you right now.'
        : 'Nothing is waiting on you. The demo script raises requests as it runs.',
    );
    return;
  }

  const ordered = [
    ...state.approvals.filter((approval) => approval.status === 'pending'),
    ...state.approvals.filter((approval) => approval.status !== 'pending'),
  ];

  const list = el('div', 'approvals');
  list.setAttribute('data-testid', 'approvals');

  for (const approval of ordered) {
    const card = el('article', 'approval');
    card.dataset.approvalId = approval.id;
    card.dataset.status = approval.status;

    const head = el('div', 'approval__head');
    head.append(el('h3', 'approval__title', approval.title));
    const risk = el('span', `chip chip--risk-${approval.risk}`, `${approval.risk} risk`);
    head.append(risk);
    card.append(head);

    if (approval.detail) card.append(el('p', 'approval__detail', approval.detail));

    const foot = el('div', 'approval__foot');
    foot.append(el('span', 'chip', agentLabel(state.agents, approval.agent)));

    if (approval.status === 'pending') {
      const allow = button('btn btn--primary', 'Allow');
      allow.type = 'button';
      allow.dataset.decision = 'allow';
      allow.disabled = actions.busy;
      allow.addEventListener('click', () => actions.decide(approval.id, 'allow'));

      const deny = button('btn btn--danger', 'Deny');
      deny.type = 'button';
      deny.dataset.decision = 'deny';
      deny.disabled = actions.busy;
      deny.addEventListener('click', () => actions.decide(approval.id, 'deny'));

      foot.append(allow, deny);
    } else {
      const label = RESOLVED_LABEL[approval.status] ?? approval.status;
      foot.append(el('span', 'approval__state', label));
    }

    card.append(foot);
    list.append(card);
  }

  root.append(list);
}
