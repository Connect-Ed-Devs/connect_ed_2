/**
 * The task board — the signature cto.new surface: four columns, cards that move.
 *
 * The order of the columns is the pipeline, so the DOM is rebuilt in column order every
 * render; a card does not animate between columns, it simply is where the state says it
 * is. That keeps render a pure function of state and makes the view trivially testable.
 */

import { COLUMNS, COLUMN_HINTS, COLUMN_LABELS } from '/src/state/board.mjs';
import { agentLabel, clear, el, emptyState, relativeTime } from '/dom.js';

/**
 * @param {HTMLElement} root
 * @param {import('/src/state/board.mjs').SkWorkspaceState} state
 * @param {{ now: number }} options
 */
export function renderBoard(root, state, options) {
  clear(root);
  const now = options.now;

  /** @type {Map<string, import('/src/state/board.mjs').SkTask[]>} */
  const byColumn = new Map(COLUMNS.map((column) => [column, []]));
  for (const task of state.tasks) {
    const column = byColumn.has(task.column) ? task.column : 'draft';
    byColumn.get(column)?.push(task);
  }

  const board = el('div', 'board');
  board.setAttribute('data-testid', 'board');

  for (const column of COLUMNS) {
    const tasks = byColumn.get(column) ?? [];
    const section = el('section', 'column');
    section.dataset.column = column;
    section.setAttribute('aria-label', `${COLUMN_LABELS[column]}: ${tasks.length} task(s)`);

    const head = el('div', 'column__head');
    const dot = el('span', 'legend__dot');
    dot.dataset.column = column;
    head.append(dot, el('span', 'column__name', COLUMN_LABELS[column]), el('span', 'column__count', String(tasks.length)));
    section.append(head);

    if (tasks.length === 0) {
      section.append(el('p', 'column__empty', COLUMN_HINTS[column]));
    } else {
      for (const task of tasks) {
        const card = el('article', 'card');
        card.dataset.taskId = task.id;
        card.append(el('h3', 'card__title', task.title));
        if (task.detail) card.append(el('p', 'card__detail', task.detail));
        const foot = el('div', 'card__foot');
        foot.append(el('span', 'chip', agentLabel(state.agents, task.agent)));
        const age = relativeTime(task.at, now);
        if (age) foot.append(el('span', undefined, age));
        card.append(foot);
        section.append(card);
      }
    }

    board.append(section);
  }

  root.append(board);
}
