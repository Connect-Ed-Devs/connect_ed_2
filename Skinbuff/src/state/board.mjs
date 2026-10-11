/**
 * The Skinbuff workspace state engine.
 *
 * Pure ESM with no Node and no DOM built-ins, so the very same file is imported by
 * the server (which turns orchestrator traffic and fixtures into this shape) and by the
 * renderer (which applies events to it). One implementation of "what a workspace is",
 * which is what keeps the two halves from drifting.
 *
 * The Freebuff orchestrator's own payload shapes are NOT pinned — every read route
 * answered `401 unauthorized` to an unauthenticated probe, and the launch secret that
 * would have changed that is deliberately unavailable to any other process (see
 * docs/api-contract.md). So nothing here assumes a shape: `normalizeSnapshot` coerces
 * whatever arrives and drops what it cannot read, and `classifyEvent` returns `null`
 * for anything it does not recognise. A shape change upstream degrades to an empty
 * panel, never to a thrown error in the render loop.
 */

/** @typedef {'draft' | 'running' | 'review' | 'done'} Column */

/** @type {Column[]} */
export const COLUMNS = ['draft', 'running', 'review', 'done'];

/** @type {Record<Column, string>} */
export const COLUMN_LABELS = {
  draft: 'Draft',
  running: 'Running',
  review: 'Review',
  done: 'Done',
};

/** @type {Record<Column, string>} */
export const COLUMN_HINTS = {
  draft: 'Planned, not started',
  running: 'Agents working now',
  review: 'Waiting on you',
  done: 'Merged or closed',
};

/** @type {string[]} */
export const AGENT_STATUSES = ['idle', 'working', 'blocked', 'done'];

/**
 * @typedef {object} SkMessage
 * @property {string} id
 * @property {string} role    'user' | 'lead' | 'agent' | 'system'
 * @property {string} [agent]
 * @property {string} text
 * @property {string} at
 */

/**
 * @typedef {object} SkTask
 * @property {string} id
 * @property {string} title
 * @property {string} detail
 * @property {string} agent
 * @property {Column} column
 * @property {string} at
 */

/**
 * @typedef {object} SkAgent
 * @property {string} id
 * @property {string} name
 * @property {string} role
 * @property {string} model
 * @property {string} status   one of AGENT_STATUSES
 * @property {string} task
 * @property {SkActivity[]} activity
 */

/**
 * @typedef {object} SkActivity
 * @property {string} at
 * @property {string} text
 */

/**
 * @typedef {object} SkApproval
 * @property {string} id
 * @property {string} title
 * @property {string} detail
 * @property {string} agent
 * @property {'low' | 'medium' | 'high'} risk
 * @property {string} at
 * @property {'pending' | 'allowed' | 'denied'} status
 */

/**
 * @typedef {object} SkWorkspaceState
 * @property {'live' | 'demo'} mode
 * @property {{ name: string, project: string, branch: string, startedAt: string }} workspace
 * @property {{ name: string, model: string }} lead
 * @property {SkMessage[]} messages
 * @property {SkAgent[]} agents
 * @property {SkTask[]} tasks
 * @property {SkApproval[]} approvals
 * @property {SkActivity[]} activity
 * @property {number} sequence
 */

/** @returns {SkWorkspaceState} */
export function emptyState() {
  return {
    mode: 'demo',
    workspace: { name: 'Skinbuff', project: '', branch: '', startedAt: '' },
    lead: { name: 'Lead', model: '' },
    messages: [],
    agents: [],
    tasks: [],
    approvals: [],
    activity: [],
    sequence: 0,
  };
}

/** @param {unknown} value */
function asText(value) {
  return typeof value === 'string' ? value : '';
}

/** @param {unknown} value @param {string} fallback */
function asId(value, fallback) {
  if (typeof value === 'string' && value) return value;
  if (typeof value === 'number' && Number.isFinite(value)) return String(value);
  return fallback;
}

/** @param {unknown} value */
function asArray(value) {
  return Array.isArray(value) ? value : [];
}

/** @param {unknown} value @returns {Record<string, unknown>} */
function asRecord(value) {
  return value && typeof value === 'object' ? /** @type {Record<string, unknown>} */ (value) : {};
}

/**
 * Map anything to a known column. Unknown values become `draft` rather than being
 * dropped, because a task that exists is more useful misfiled than invisible.
 *
 * @param {unknown} value
 * @returns {Column}
 */
export function toColumn(value) {
  // Matched against the joined words rather than the exact string, because the status
  // words an agent emits are freeform phrases ("waiting on you", "in progress") and only
  // the leading word is predictable. A single word such as `active` is matched as a word
  // so `inactive` cannot slip into `running` on a substring.
  const words = asText(value).toLowerCase().split(/[^a-z0-9]+/).filter(Boolean);
  const raw = words.join('');
  if (!raw) return 'draft';
  if (words.some((word) => word === 'wip' || word === 'active' || word === 'doing')) return 'running';
  if (/(progress|running|working|started|building)/.test(raw)) return 'running';
  if (/(review|waiting|blocked|approval|pending|verify|await)/.test(raw)) return 'review';
  if (/(done|complete|merged|closed|shipped|finished|cancel)/.test(raw)) return 'done';
  return 'draft';
}

/** @param {unknown} value */
export function toAgentStatus(value) {
  const raw = asText(value).toLowerCase().replace(/[\s_-]+/g, '');
  if (raw === 'working' || raw === 'busy' || raw === 'running') return 'working';
  if (raw === 'blocked' || raw === 'error' || raw === 'failed') return 'blocked';
  if (raw === 'done' || raw === 'complete' || raw === 'completed' || raw === 'idle') {
    return raw.startsWith('done') || raw.startsWith('complete') ? 'done' : 'idle';
  }
  return 'idle';
}

/** @param {unknown} value @returns {SkRisk} */
function toRisk(value) {
  const raw = asText(value).toLowerCase();
  if (raw === 'high' || raw === 'medium' || raw === 'low') return raw;
  return 'medium';
}

/** @typedef {'low' | 'medium' | 'high'} SkRisk */

/** @param {unknown} agent */
function normalizeActivity(agent) {
  return asArray(asRecord(agent).activity)
    .map((entry) => {
      if (typeof entry === 'string') return { at: '', text: entry };
      const record = asRecord(entry);
      return { at: asText(record.at ?? record.time ?? record.ts), text: asText(record.text ?? record.message) };
    })
    .filter((entry) => entry.text)
    .slice(-30);
}

/**
 * Coerce an arbitrarily shaped snapshot into a valid workspace state. Missing pieces
 * stay empty; nothing throws.
 *
 * @param {unknown} snapshot
 * @param {'live' | 'demo'} mode
 * @returns {SkWorkspaceState}
 */
export function normalizeSnapshot(snapshot, mode) {
  const root = asRecord(snapshot);
  const state = emptyState();
  state.mode = mode;

  const workspace = asRecord(root.workspace ?? root.project);
  state.workspace = {
    name: asText(workspace.name ?? root.name) || 'Workspace',
    project: asText(workspace.project ?? workspace.path ?? root.projectPath),
    branch: asText(workspace.branch ?? root.branch),
    startedAt: asText(workspace.startedAt ?? root.startedAt),
  };

  const lead = asRecord(root.lead);
  state.lead = {
    name: asText(lead.name) || 'Lead',
    model: asText(lead.model),
  };

  state.messages = asArray(root.messages)
    .map((entry, index) => {
      const record = asRecord(entry);
      const role = asText(record.role).toLowerCase();
      return {
        id: asId(record.id, `m${index}`),
        role: role === 'user' || role === 'lead' || role === 'agent' || role === 'system' ? role : 'system',
        agent: asText(record.agent),
        text: asText(record.text ?? record.content ?? record.message),
        at: asText(record.at ?? record.time ?? record.createdAt),
      };
    })
    .filter((message) => message.text);

  state.tasks = asArray(root.tasks)
    .map((entry, index) => {
      const record = asRecord(entry);
      return {
        id: asId(record.id, `t${index}`),
        title: asText(record.title ?? record.name) || 'Untitled task',
        detail: asText(record.detail ?? record.description),
        agent: asText(record.agent ?? record.assignee),
        column: toColumn(record.column ?? record.status ?? record.state),
        at: asText(record.at ?? record.updatedAt ?? record.createdAt),
      };
    })
    .filter((task) => task.id);

  state.agents = asArray(root.agents)
    .map((entry, index) => {
      const record = asRecord(entry);
      return {
        id: asId(record.id, `a${index}`),
        name: asText(record.name) || 'Agent',
        role: asText(record.role) || 'Specialist',
        model: asText(record.model),
        status: toAgentStatus(record.status ?? record.state),
        task: asText(record.task ?? record.taskTitle),
        activity: normalizeActivity(record),
      };
    })
    .filter((agent) => agent.id);

  state.approvals = asArray(root.approvals)
    .map((entry, index) => {
      const record = asRecord(entry);
      const status = asText(record.status).toLowerCase();
      /** Anything that is not a known resolution is still waiting on the user. @type {'pending' | 'allowed' | 'denied'} */
      const resolved = status === 'allowed' || status === 'denied' ? status : 'pending';
      return {
        id: asId(record.id, `p${index}`),
        title: asText(record.title) || 'Approval requested',
        detail: asText(record.detail ?? record.description),
        agent: asText(record.agent),
        risk: toRisk(record.risk),
        at: asText(record.at ?? record.requestedAt),
        status: resolved,
      };
    })
    .filter((approval) => approval.id);

  state.activity = asArray(root.activity)
    .map((entry) => {
      if (typeof entry === 'string') return { at: '', text: entry };
      const record = asRecord(entry);
      return { at: asText(record.at ?? record.time), text: asText(record.text ?? record.message) };
    })
    .filter((entry) => entry.text)
    .slice(-40);

  return state;
}

/**
 * Recognise an event from the orchestrator (or from the demo replay) and give it a
 * canonical name. Returns `null` for anything unrecognised, which callers treat as a
 * no-op rather than an error.
 *
 * Accepted envelopes, because the real one is unknown:
 *   { type: 'task.created', ... }            ·  { type: 'task_created', ... }
 *   { event: 'task.created', data: {...} }   ·  { kind: 'task.created', payload: {...} }
 *
 * @param {unknown} raw
 * @returns {{ type: string } & Record<string, unknown> | null}
 */
export function classifyEvent(raw) {
  const envelope = asRecord(raw);
  const nested = asRecord(envelope.data ?? envelope.payload ?? envelope.body);

  const rawName = asText(envelope.type ?? envelope.event ?? envelope.kind ?? envelope.name);
  if (!rawName) return null;
  const type = rawName.trim().toLowerCase().replace(/[\s-]+/g, '_').replace(/\./g, '.');
  const body = Object.keys(nested).length > 0 ? nested : envelope;

  switch (type) {
    case 'task.created':
    case 'task_created':
    case 'task.added':
      return { type: 'task.created', task: asRecord(body.task ?? body) };
    case 'task.updated':
    case 'task_updated':
      return { type: 'task.updated', task: asRecord(body.task ?? body) };
    case 'task.moved':
    case 'task_moved':
    case 'task.status':
      return { type: 'task.moved', task: asRecord(body.task ?? body) };
    case 'agent.updated':
    case 'agent_updated':
    case 'agent.status':
      return { type: 'agent.updated', agent: asRecord(body.agent ?? body) };
    case 'agent.activity':
    case 'agent_activity':
    case 'agent.log':
      return { type: 'agent.activity', agent: asRecord(body.agent ?? body) };
    case 'message':
    case 'message.created':
    case 'chat.message':
      return { type: 'message', message: asRecord(body.message ?? body) };
    case 'approval.requested':
    case 'approval_requested':
    case 'approval.request':
      return { type: 'approval.requested', approval: asRecord(body.approval ?? body) };
    case 'approval.resolved':
    case 'approval_resolved':
      return { type: 'approval.resolved', approval: asRecord(body.approval ?? body) };
    case 'session':
    case 'session.updated':
    case 'workspace':
      return { type: 'session', workspace: asRecord(body.workspace ?? body) };
    default:
      return null;
  }
}

/** @param {SkTask[]} tasks @param {string} id */
function findTask(tasks, id) {
  return tasks.find((task) => task.id === id) ?? null;
}

/**
 * Apply one normalised event, returning a new state. Immutable so a re-render is a
 * pure function of state and a test can assert the step from A to B.
 *
 * @param {SkWorkspaceState} state
 * @param {{ type: string } & Record<string, unknown>} event
 * @returns {SkWorkspaceState}
 */
export function applyEvent(state, event) {
  const next = { ...state, sequence: state.sequence + 1 };
  const record = asRecord(event);

  if (event.type === 'task.created') {
    const task = asRecord(record.task);
    const id = asId(task.id, `t${next.sequence}`);
    if (findTask(next.tasks, id)) return next;
    next.tasks = [
      ...next.tasks,
      {
        id,
        title: asText(task.title ?? task.name) || 'Untitled task',
        detail: asText(task.detail ?? task.description),
        agent: asText(task.agent ?? task.assignee),
        column: toColumn(task.column ?? task.status),
        at: asText(task.at ?? task.createdAt),
      },
    ];
    return next;
  }

  if (event.type === 'task.updated' || event.type === 'task.moved') {
    const task = asRecord(record.task);
    const id = asId(task.id, '');
    if (!id) return next;
    const columnField = event.type === 'task.moved' ? task.column ?? task.status ?? task.to : task.column;
    next.tasks = next.tasks.map((existing) =>
      existing.id === id
        ? {
            ...existing,
            title: asText(task.title) || existing.title,
            detail: asText(task.detail ?? task.description) || existing.detail,
            agent: asText(task.agent ?? task.assignee) || existing.agent,
            column: columnField === undefined ? existing.column : toColumn(columnField),
            at: asText(task.at ?? task.updatedAt) || existing.at,
          }
        : existing,
    );
    return next;
  }

  if (event.type === 'agent.updated') {
    const agent = asRecord(record.agent);
    const id = asId(agent.id, asText(agent.name));
    if (!id) return next;
    const exists = next.agents.some((existing) => existing.id === id);
    if (!exists) {
      next.agents = [
        ...next.agents,
        {
          id,
          name: asText(agent.name) || id,
          role: asText(agent.role) || 'Specialist',
          model: asText(agent.model),
          status: toAgentStatus(agent.status ?? agent.state),
          task: asText(agent.task ?? agent.taskTitle),
          activity: [],
        },
      ];
      return next;
    }
    next.agents = next.agents.map((existing) =>
      existing.id === id
        ? {
            ...existing,
            name: asText(agent.name) || existing.name,
            role: asText(agent.role) || existing.role,
            model: asText(agent.model) || existing.model,
            status: agent.status === undefined && agent.state === undefined
              ? existing.status
              : toAgentStatus(agent.status ?? agent.state),
            task: asText(agent.task ?? agent.taskTitle) || existing.task,
          }
        : existing,
    );
    return next;
  }

  if (event.type === 'agent.activity') {
    const agent = asRecord(record.agent);
    const id = asId(agent.id, asText(agent.name));
    const text = asText(agent.text ?? agent.message ?? record.text);
    if (!id || !text) return next;
    const entry = { at: asText(agent.at ?? agent.time), text };
    next.activity = [...next.activity, entry].slice(-40);
    next.agents = next.agents.map((existing) =>
      existing.id === id ? { ...existing, activity: [...existing.activity, entry].slice(-30) } : existing,
    );
    return next;
  }

  if (event.type === 'message') {
    const message = asRecord(record.message);
    const text = asText(message.text ?? message.content);
    if (!text) return next;
    const role = asText(message.role).toLowerCase();
    const id = asId(message.id, `m${next.sequence}`);
    // The renderer shows a message it just sent under an id it chose, and the server
    // echoes that same id back on the stream. Ignoring the echo (and any other repeat of
    // an id already present) is what keeps a message appearing exactly once rather than
    // twice, without the client having to track which frames are its own.
    if (next.messages.some((existing) => existing.id === id)) return next;
    next.messages = [
      ...next.messages,
      {
        id,
        role: role === 'user' || role === 'lead' || role === 'agent' || role === 'system' ? role : 'agent',
        agent: asText(message.agent),
        text,
        at: asText(message.at ?? message.time),
      },
    ];
    return next;
  }

  if (event.type === 'approval.requested') {
    const approval = asRecord(record.approval);
    const id = asId(approval.id, `p${next.sequence}`);
    if (next.approvals.some((existing) => existing.id === id)) return next;
    next.approvals = [
      ...next.approvals,
      {
        id,
        title: asText(approval.title) || 'Approval requested',
        detail: asText(approval.detail ?? approval.description),
        agent: asText(approval.agent),
        risk: toRisk(approval.risk),
        at: asText(approval.at ?? approval.requestedAt),
        status: 'pending',
      },
    ];
    return next;
  }

  if (event.type === 'approval.resolved') {
    const approval = asRecord(record.approval);
    const id = asId(approval.id, '');
    const decision = asText(approval.decision ?? approval.status).toLowerCase();
    if (!id) return next;
    next.approvals = next.approvals.map((existing) =>
      existing.id === id
        ? { ...existing, status: decision === 'deny' || decision === 'denied' ? 'denied' : 'allowed' }
        : existing,
    );
    return next;
  }

  if (event.type === 'session') {
    const workspace = asRecord(record.workspace);
    next.workspace = {
      name: asText(workspace.name) || next.workspace.name,
      project: asText(workspace.project ?? workspace.path) || next.workspace.project,
      branch: asText(workspace.branch) || next.workspace.branch,
      startedAt: asText(workspace.startedAt) || next.workspace.startedAt,
    };
    return next;
  }

  return next;
}

/** @param {SkWorkspaceState} state */
export function deriveStats(state) {
  /** @type {Record<Column, number>} */
  const columns = { draft: 0, running: 0, review: 0, done: 0 };
  for (const task of state.tasks) columns[task.column] += 1;

  /** @type {Record<string, number>} */
  const agents = { idle: 0, working: 0, blocked: 0, done: 0 };
  for (const agent of state.agents) agents[agent.status] = (agents[agent.status] ?? 0) + 1;

  return {
    columns,
    agents,
    openTasks: columns.draft + columns.running + columns.review,
    pendingApprovals: state.approvals.filter((approval) => approval.status === 'pending').length,
  };
}
