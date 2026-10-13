/**
 * The demo workspace.
 *
 * Skinbuff has two modes and this file is the second one. When the Freebuff
 * orchestrator is not reachable — the app is closed, or Skinbuff is opened on its own —
 * the skin still has to render, be reviewable, and be testable. So the same shapes the
 * live adapter produces are produced here, deterministically: no `Date.now()`, no
 * `Math.random()`, so an assertion can name an exact value.
 *
 * `demoEvents` deliberately mixes event envelopes (`type`, a snake_case alias, and an
 * `{ event, data }` wrapper) to exercise `classifyEvent`'s tolerance — the real
 * orchestrator's envelope is unknown, and the code that copes with that should be the
 * code the demo drives.
 */

/** @type {string} */
const T0 = '2026-10-11T09:00:00.000Z';

/** @param {number} minutes */
function at(minutes) {
  return new Date(Date.parse(T0) + minutes * 60_000).toISOString();
}

/** The snapshot the demo starts from: a workspace already mid-flight. */
export function demoSnapshot() {
  return {
    workspace: {
      name: 'Skinbuff',
      project: 'AIWork/Connect Ed',
      branch: 'Experimental-Features',
      startedAt: at(0),
    },
    lead: { name: 'Lead', model: 'freebuff-desktop' },
    messages: [
      {
        id: 'm1',
        role: 'system',
        text: 'Attached to the Freebuff orchestrator in demo mode — no live session in this window.',
        at: at(0),
      },
      {
        id: 'm2',
        role: 'user',
        text: 'Reskin the attendance screen so teachers can mark a whole class in one pass.',
        at: at(1),
      },
      {
        id: 'm3',
        role: 'lead',
        agent: 'Lead',
        text: 'Split into four: a data path for bulk marking, the screen itself, the offline queue, and tests. Three need your approval before they touch the repo.',
        at: at(2),
      },
    ],
    agents: [
      {
        id: 'a-data',
        name: 'Data',
        role: 'Persistence',
        model: 'fast',
        status: 'working',
        task: 'Bulk attendance write path',
        activity: [
          { at: at(3), text: 'read lib/models/attendance.dart' },
          { at: at(4), text: 'draft: AttendanceBatch.fromRoster()' },
        ],
      },
      {
        id: 'a-ui',
        name: 'Screen',
        role: 'Flutter UI',
        model: 'standard',
        status: 'working',
        task: 'One-pass marking screen',
        activity: [{ at: at(3), text: 'opened lib/screens/attendance_screen.dart' }],
      },
      {
        id: 'a-offline',
        name: 'Offline',
        role: 'Sync & queue',
        model: 'fast',
        status: 'blocked',
        task: 'Queue replay on reconnect',
        activity: [{ at: at(5), text: 'waiting: needs the batch write shape' }],
      },
      {
        id: 'a-test',
        name: 'Verifier',
        role: 'Tests',
        model: 'fast',
        status: 'idle',
        task: 'Widget + unit coverage',
        activity: [],
      },
    ],
    tasks: [
      {
        id: 't1',
        title: 'Bulk attendance write path',
        detail: 'One transaction per class instead of one per student.',
        agent: 'a-data',
        column: 'running',
        at: at(3),
      },
      {
        id: 't2',
        title: 'One-pass marking screen',
        detail: 'Grid of students with present/absent/late toggles and a single save.',
        agent: 'a-ui',
        column: 'running',
        at: at(3),
      },
      {
        id: 't3',
        title: 'Offline queue replay',
        detail: 'Replay queued marks when connectivity returns, newest wins.',
        agent: 'a-offline',
        column: 'review',
        at: at(5),
      },
      {
        id: 't4',
        title: 'Widget coverage for the grid',
        detail: 'Cover empty roster, all-present and all-absent.',
        agent: 'a-test',
        column: 'draft',
        at: at(6),
      },
      {
        id: 't5',
        title: 'Extract the roster query',
        detail: 'Moved out of the screen so it can be cached.',
        agent: 'a-data',
        column: 'done',
        at: at(2),
      },
    ],
    approvals: [
      {
        id: 'p1',
        title: 'Edit lib/screens/attendance_screen.dart',
        detail: 'Rewrites the marking loop and removes the per-student save button.',
        agent: 'a-ui',
        risk: 'medium',
        at: at(6),
        status: 'pending',
      },
      {
        id: 'p2',
        title: 'Run freezed / build_runner',
        detail: 'Regenerates model code for AttendanceBatch.',
        agent: 'a-data',
        risk: 'low',
        at: at(7),
        status: 'pending',
      },
      {
        id: 'p3',
        title: 'Force-push to a shared branch',
        detail: 'Requested by the offline agent to resolve a rebase.',
        agent: 'a-offline',
        risk: 'high',
        at: at(8),
        status: 'pending',
      },
    ],
    activity: [
      { at: at(2), text: 'Workspace read: 412 files, branch Experimental-Features' },
      { at: at(3), text: 'Team of 4 dispatched' },
      { at: at(5), text: 'Offline blocked on Data' },
    ],
  };
}

/**
 * A scripted timeline. Each entry is applied in order by the demo event source, one
 * per tick, so the UI is exercised the way a live stream would exercise it.
 */
export function demoEvents() {
  return [
    { type: 'agent.status', agent: { id: 'a-offline', status: 'working', task: 'Queue replay on reconnect' } },
    { type: 'task.moved', task: { id: 't3', column: 'running' } },
    { event: 'agent_activity', data: { agent: { id: 'a-data', text: 'wrote lib/models/attendance_batch.dart', at: at(9) } } },
    { type: 'approval.requested', approval: {
      id: 'p4',
      title: 'Add dependency: connectivity_plus',
      detail: 'For reconnect detection in the offline queue.',
      agent: 'a-offline',
      risk: 'low',
      at: at(10),
    } },
    { kind: 'message', payload: { message: { role: 'agent', agent: 'Data', text: 'Batch write path is in; the queue can start replaying.', at: at(11) } } },
    { type: 'approval.resolved', approval: { id: 'p2', decision: 'allow' } },
    { event: 'task_created', data: { task: { id: 't6', title: 'Replay conflict policy', detail: 'Decide who wins when a queued mark meets a newer one.', agent: 'a-offline', column: 'draft', at: at(12) } } },
    { type: 'agent.updated', agent: { id: 'a-test', status: 'working', task: 'Widget + unit coverage' } },
    { type: 'approval.resolved', approval: { id: 'p3', decision: 'deny' } },
    { type: 'message', message: { role: 'lead', agent: 'Lead', text: 'Force-push denied. Offline will rebase locally instead.', at: at(13) } },
    { type: 'task.moved', task: { id: 't5', column: 'done' } },
    { type: 'session', workspace: { name: 'Skinbuff', project: 'AIWork/Connect Ed', branch: 'Experimental-Features' } },
  ];
}

/**
 * The canned answer the demo returns for a prompt. Named separately from the composer
 * so a test can assert the reply without parsing prose out of the UI.
 *
 * @param {string} text
 */
export function demoReply(text) {
  const trimmed = text.trim();
  const restated = trimmed.length > 120 ? `${trimmed.slice(0, 117)}…` : trimmed;
  return {
    id: `reply-${trimmed.length}`,
    role: 'lead',
    agent: 'Lead',
    text: restated
      ? `Demo Lead here — no live orchestrator is attached, so I cannot act on “${restated}”. Start the app with \`npm run attach\` and this goes to the real agent.`
      : 'Demo Lead here — no live orchestrator is attached, so there is nothing to run. Start the app with `npm run attach`.',
    at: '',
  };
}

/**
 * The demo's answer to an approval decision, used when nothing live is attached.
 *
 * @param {'allow' | 'deny'} decision
 */
export function demoDecision(decision) {
  return decision === 'deny'
    ? 'Denied. Nothing was written.'
    : 'Allowed. In demo mode nothing is executed — attach to the real app to run it.';
}
