import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  applyEvent,
  classifyEvent,
  COLUMNS,
  deriveStats,
  emptyState,
  normalizeSnapshot,
  toAgentStatus,
  toColumn,
} from '../src/state/board.mjs';

describe('normalizeSnapshot', () => {
  test('coerces garbage into a valid, empty state instead of throwing', () => {
    for (const input of [null, undefined, 0, 'nope', [], { tasks: 'not an array' }, { agents: [null, 7] }]) {
      const state = normalizeSnapshot(input, 'demo');
      assert.deepEqual(state.tasks, []);
      assert.equal(state.mode, 'demo');
      assert.ok(Array.isArray(state.messages));
    }
  });

  test('reads a well-formed snapshot including partial fields', () => {
    const state = normalizeSnapshot(
      {
        workspace: { name: 'Skinbuff', project: 'p', branch: 'b' },
        lead: { name: 'Lead', model: 'm' },
        messages: [{ id: 'm1', role: 'lead', text: 'hello' }],
        tasks: [{ id: 't1', title: 'T', column: 'in progress' }],
        agents: [{ id: 'a1', name: 'A', status: 'busy' }],
        approvals: [{ id: 'p1', title: 'P', status: 'weird' }],
      },
      'live',
    );
    assert.equal(state.mode, 'live');
    assert.equal(state.workspace.branch, 'b');
    assert.equal(state.tasks.length, 1);
    // 'in progress' is the orchestrator's vocabulary, mapped to the board's.
    assert.equal(state.tasks[0]!.column, 'running');
    assert.equal(state.agents[0]!.status, 'working');
    // An unrecognised approval status is treated as still pending, not as resolved.
    assert.equal(state.approvals[0]!.status, 'pending');
  });

  test('drops messages and activities with no text rather than rendering blanks', () => {
    const state = normalizeSnapshot(
      { messages: [{ id: 'a', text: '' }, { id: 'b', text: 'kept' }], activity: ['', 'line'] },
      'demo',
    );
    assert.deepEqual(state.messages.map((message) => message.id), ['b']);
    assert.deepEqual(state.activity.map((entry) => entry.text), ['line']);
  });
});

describe('vocabulary mapping', () => {
  test('maps orchestrator column words onto the four board columns', () => {
    assert.equal(toColumn('in_progress'), 'running');
    assert.equal(toColumn('Running'), 'running');
    assert.equal(toColumn('waiting on you'), 'review');
    assert.equal(toColumn('merged'), 'done');
    assert.equal(toColumn('whatever'), 'draft');
    assert.ok(COLUMNS.includes(toColumn('nonsense') as (typeof COLUMNS)[number]));
  });

  test('maps agent status words, defaulting to idle', () => {
    assert.equal(toAgentStatus('busy'), 'working');
    assert.equal(toAgentStatus('failed'), 'blocked');
    assert.equal(toAgentStatus('completed'), 'done');
    assert.equal(toAgentStatus(undefined), 'idle');
  });
});

describe('classifyEvent', () => {
  test('accepts the envelopes an unknown producer might use', () => {
    assert.equal(classifyEvent({ type: 'task.created', task: { id: 't' } })?.type, 'task.created');
    assert.equal(classifyEvent({ type: 'task_created', task: { id: 't' } })?.type, 'task.created');
    assert.equal(classifyEvent({ event: 'task.created', data: { task: { id: 't' } } })?.type, 'task.created');
    assert.equal(classifyEvent({ kind: 'message', payload: { message: { text: 'x' } } })?.type, 'message');
    assert.equal(classifyEvent({ type: 'Task Created', task: {} })?.type, 'task.created');
  });

  test('returns null for anything it does not recognise, so a render loop never throws', () => {
    for (const input of [null, {}, { type: '' }, { type: 'ads.impression' }, 'string', 42]) {
      assert.equal(classifyEvent(input), null);
    }
  });

  test('unwraps the nested body so the reducer reads the inner object', () => {
    const event = classifyEvent({ event: 'agent_activity', data: { agent: { id: 'a1', text: 'hi' } } });
    assert.deepEqual(event?.agent, { id: 'a1', text: 'hi' });
  });
});

describe('applyEvent', () => {
  test('creates a task once and ignores a duplicate create with the same id', () => {
    let state = emptyState();
    state = applyEvent(state, { type: 'task.created', task: { id: 't1', title: 'One' } });
    state = applyEvent(state, { type: 'task.created', task: { id: 't1', title: 'One again' } });
    assert.equal(state.tasks.length, 1);
    assert.equal(state.tasks[0]!.title, 'One');
  });

  test('moves a task between columns, and ignores a move for an unknown task', () => {
    let state = applyEvent(emptyState(), { type: 'task.created', task: { id: 't1', title: 'One' } });
    state = applyEvent(state, { type: 'task.moved', task: { id: 't1', column: 'review' } });
    assert.equal(state.tasks[0]!.column, 'review');
    state = applyEvent(state, { type: 'task.moved', task: { id: 'ghost', column: 'done' } });
    assert.equal(state.tasks.length, 1);
    assert.equal(state.tasks[0]!.column, 'review');
  });

  test('treats a move without a column as a no-op rather than a demotion to draft', () => {
    let state = applyEvent(emptyState(), { type: 'task.created', task: { id: 't1', title: 'One', column: 'done' } });
    state = applyEvent(state, { type: 'task.updated', task: { id: 't1', detail: 'more' } });
    assert.equal(state.tasks[0]!.column, 'done');
    assert.equal(state.tasks[0]!.detail, 'more');
  });

  test('creates an agent on first sight, then patches it without losing prior fields', () => {
    let state = applyEvent(emptyState(), { type: 'agent.updated', agent: { id: 'a1', name: 'Data', role: 'Persistence' } });
    state = applyEvent(state, { type: 'agent.updated', agent: { id: 'a1', status: 'working', task: 'Write path' } });
    assert.equal(state.agents.length, 1);
    assert.equal(state.agents[0]!.name, 'Data');
    assert.equal(state.agents[0]!.status, 'working');
    assert.equal(state.agents[0]!.task, 'Write path');
  });

  test('appends agent activity to both the roster entry and the workspace feed', () => {
    let state = applyEvent(emptyState(), { type: 'agent.updated', agent: { id: 'a1', name: 'Data' } });
    state = applyEvent(state, { type: 'agent.activity', agent: { id: 'a1', text: 'read a file' } });
    assert.equal(state.agents[0]!.activity.length, 1);
    assert.equal(state.activity.length, 1);
  });

  test('does not mutate the state it was given', () => {
    const before = applyEvent(emptyState(), { type: 'task.created', task: { id: 't1', title: 'One' } });
    const snapshot = JSON.stringify(before);
    applyEvent(before, { type: 'task.moved', task: { id: 't1', column: 'done' } });
    assert.equal(JSON.stringify(before), snapshot);
  });

  test('keeps a message that is echoed back under the id the sender chose, exactly once', () => {
    let state = emptyState();
    const sent = { id: 'local-1', role: 'user', text: 'mark the class' };
    state = applyEvent(state, { type: 'message', message: sent });
    state = applyEvent(state, { type: 'message', message: { ...sent } });
    assert.equal(state.messages.length, 1);

    state = applyEvent(state, { type: 'message', message: { id: 'lead-1', role: 'lead', text: 'on it' } });
    assert.equal(state.messages.length, 2);
    assert.deepEqual(state.messages.map((message) => message.id), ['local-1', 'lead-1']);
  });

  test('resolves an approval either way, and treats an unknown decision as allowed', () => {
    let state = applyEvent(emptyState(), { type: 'approval.requested', approval: { id: 'p1', title: 'Write' } });
    assert.equal(state.approvals[0]!.status, 'pending');
    state = applyEvent(state, { type: 'approval.resolved', approval: { id: 'p1', decision: 'deny' } });
    assert.equal(state.approvals[0]!.status, 'denied');
    state = applyEvent(state, { type: 'approval.resolved', approval: { id: 'p1', decision: 'something else' } });
    assert.equal(state.approvals[0]!.status, 'allowed');
  });

  test('ignores events whose payload is unusable without changing the state', () => {
    const state = applyEvent(emptyState(), { type: 'task.created', task: { id: 't1', title: 'One' } });
    for (const event of [
      { type: 'task.updated', task: {} },
      { type: 'message', message: { text: '' } },
      { type: 'approval.resolved', approval: {} },
      { type: 'agent.activity', agent: { id: 'a1' } },
    ]) {
      const next = applyEvent(state, event);
      assert.equal(next.tasks.length, 1);
      assert.equal(next.messages.length, 0);
    }
  });

  test('an unrecognised event type is a no-op', () => {
    const state = applyEvent(emptyState(), { type: 'ads.impression' });
    assert.deepEqual(state.tasks, []);
    assert.equal(state.sequence, 1);
  });
});

describe('deriveStats', () => {
  test('counts columns, agent states and pending approvals', () => {
    let state = emptyState();
    state = applyEvent(state, { type: 'task.created', task: { id: 't1' } });
    state = applyEvent(state, { type: 'task.created', task: { id: 't2', column: 'running' } });
    state = applyEvent(state, { type: 'task.created', task: { id: 't3', column: 'done' } });
    state = applyEvent(state, { type: 'agent.updated', agent: { id: 'a1', status: 'working' } });
    state = applyEvent(state, { type: 'agent.updated', agent: { id: 'a2', status: 'blocked' } });
    state = applyEvent(state, { type: 'approval.requested', approval: { id: 'p1' } });

    const stats = deriveStats(state);
    assert.deepEqual(stats.columns, { draft: 1, running: 1, review: 0, done: 1 });
    assert.equal(stats.openTasks, 2);
    assert.equal(stats.agents.working, 1);
    assert.equal(stats.agents.blocked, 1);
    assert.equal(stats.pendingApprovals, 1);
  });
});
