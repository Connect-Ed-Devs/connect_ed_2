/**
 * The three DOM helpers every view shares.
 *
 * Views build nodes rather than assigning `innerHTML`, because the text they render
 * comes from the orchestrator (and therefore ultimately from an agent's output). Setting
 * it as text makes a message that contains markup a message about markup.
 */

/**
 * @param {string} tag
 * @param {string} [className]
 * @param {string} [text]
 * @returns {HTMLElement}
 */
export function el(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

/**
 * A `<button>` with the element type the DOM actually reports, so a caller can set
 * `type` and `disabled` without a cast at every call site.
 *
 * @param {string} className
 * @param {string} text
 * @returns {HTMLButtonElement}
 */
export function button(className, text) {
  return /** @type {HTMLButtonElement} */ (el('button', className, text));
}

/** @param {Element} node */
export function clear(node) {
  while (node.firstChild) node.removeChild(node.firstChild);
}

/**
 * An element that is only present when it has something to say.
 *
 * @param {Element} parent
 * @param {string} className
 * @param {string} text
 */
export function emptyState(parent, className, text) {
  parent.append(el('p', className, text));
}

/**
 * A short, stable label for an agent id, so a card can name an agent the roster has not
 * seen (or name it before the roster arrives).
 *
 * @param {import('../src/state/board.mjs').SkAgent[]} agents
 * @param {string} id
 */
export function agentLabel(agents, id) {
  if (!id) return 'unassigned';
  const agent = agents.find((candidate) => candidate.id === id);
  if (agent) return agent.name;
  return id.length > 14 ? `${id.slice(0, 13)}…` : id;
}

/**
 * A relative age from an ISO string, or an empty string when the timestamp is missing or
 * unparseable (which happens: the orchestrator's shapes are not pinned).
 *
 * @param {string} at
 * @param {number} now
 */
export function relativeTime(at, now) {
  if (!at) return '';
  const parsed = Date.parse(at);
  if (Number.isNaN(parsed)) return '';
  const seconds = Math.max(0, Math.round((now - parsed) / 1000));
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours}h`;
  return `${Math.round(hours / 24)}d`;
}
