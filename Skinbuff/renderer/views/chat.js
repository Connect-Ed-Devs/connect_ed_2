/**
 * The Lead conversation.
 *
 * The one piece of statefulness here is scroll position: a conversation that has new
 * messages should follow them, but one the reader has scrolled up in should not be yanked
 * to the bottom. So the view follows the log only when the log was already at the bottom
 * before the render, which is the behaviour a reader expects and the reason this is not
 * simply `scrollTop = scrollHeight`.
 */

import { clear, el, emptyState, relativeTime } from '/dom.js';

/** @type {Record<string, string>} */
const ROLE_LABEL = { user: 'you', lead: 'lead', agent: 'agent', system: 'system' };

/**
 * @param {HTMLElement} root
 * @param {import('/src/state/board.mjs').SkWorkspaceState} state
 * @param {{ now: number }} options
 */
export function renderChat(root, state, options) {
  const wasAtBottom = root.scrollHeight - root.scrollTop - root.clientHeight < 48;
  clear(root);

  if (state.messages.length === 0) {
    emptyState(
      root,
      'panel__empty',
      state.mode === 'live'
        ? 'Attached. Say something to the Lead, or wait for the session to stream in.'
        : 'No messages yet.',
    );
    return;
  }

  for (const message of state.messages) {
    const article = el('article', `msg msg--${message.role}`);
    article.dataset.messageId = message.id;
    article.dataset.role = message.role;

    const meta = el('div', 'msg__meta');
    meta.append(el('span', 'msg__who', message.agent || message.role));
    meta.append(el('span', 'msg__role', ROLE_LABEL[message.role] ?? message.role));
    const age = relativeTime(message.at, options.now);
    if (age) meta.append(el('span', 'msg__role', age));
    article.append(meta);

    article.append(el('p', 'msg__text', message.text));
    root.append(article);
  }

  if (wasAtBottom) root.scrollTop = root.scrollHeight;
}
