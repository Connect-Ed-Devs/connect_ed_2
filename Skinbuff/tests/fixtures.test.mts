import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { demoDecision, demoEvents, demoReply, demoSnapshot } from '../src/api/fixtures.mjs';
import { applyEvent, classifyEvent, COLUMNS, deriveStats, normalizeSnapshot } from '../src/state/board.mjs';

describe('demoSnapshot', () => {
  test('normalizes into a workspace with every board column represented', () => {
    const state = normalizeSnapshot(demoSnapshot(), 'demo');
    assert.ok(state.tasks.length > 0);
    for (const column of COLUMNS) {
      assert.ok(
        state.tasks.some((task) => task.column === column),
        `expected at least one task in ${column}`,
      );
    }
    assert.ok(state.agents.length >= 3, 'expected a team, not one agent');
    assert.ok(state.messages.length >= 3);
    assert.ok(state.approvals.every((approval) => approval.status === 'pending'));
    assert.ok(state.agents.some((agent) => agent.activity.length > 0), 'expected agent activity to show');
  });

  test('is deterministic, so an assertion can name an exact value', () => {
    assert.equal(JSON.stringify(demoSnapshot()), JSON.stringify(demoSnapshot()));
    assert.equal(JSON.stringify(demoEvents()), JSON.stringify(demoEvents()));
  });

  test('assigns every task an agent the roster actually contains', () => {
    const state = normalizeSnapshot(demoSnapshot(), 'demo');
    for (const task of state.tasks) {
      assert.ok(state.agents.some((agent) => agent.id === task.agent), `no agent for ${task.agent}`);
    }
  });
});

describe('demoEvents', () => {
  test('every scripted event is recognised, which is what makes the demo exercise the reducer', () => {
    const events = demoEvents();
    assert.ok(events.length > 5);
    for (const raw of events) {
      assert.notEqual(classifyEvent(raw), null, `unclassified demo event: ${JSON.stringify(raw)}`);
    }
  });

  test('applying the whole timeline moves the workspace on in the ways it claims to', () => {
    let state = normalizeSnapshot(demoSnapshot(), 'demo');
    for (const raw of demoEvents()) {
      const event = classifyEvent(raw);
      assert.ok(event);
      state = applyEvent(state, event);
    }

    const byId = new Map(state.tasks.map((task) => [task.id, task]));
    // The scripted story: the queue starts replaying, a new task is drafted, one closes.
    assert.equal(byId.get('t3')!.column, 'running');
    assert.equal(byId.get('t6')!.column, 'draft');
    assert.equal(byId.get('t5')!.column, 'done');

    const approvals = new Map(state.approvals.map((approval) => [approval.id, approval]));
    assert.equal(approvals.get('p2')!.status, 'allowed');
    assert.equal(approvals.get('p3')!.status, 'denied');
    assert.equal(approvals.get('p4')!.status, 'pending');

    // The offline agent stops being blocked and starts working.
    const offline = state.agents.find((agent) => agent.id === 'a-offline');
    assert.equal(offline!.status, 'working');

    // Activity from a nested `data` envelope landed on the right agent.
    const data = state.agents.find((agent) => agent.id === 'a-data');
    assert.ok(data!.activity.some((entry) => entry.text.includes('attendance_batch')));

    const stats = deriveStats(state);
    assert.equal(stats.pendingApprovals, 2); // p1 and p4
    assert.equal(stats.columns.done, 1);
  });
});

describe('demoReply and demoDecision', () => {
  test('the reply quotes the prompt and says how to reach the real agent', () => {
    const reply = demoReply('  add a retry  ');
    assert.equal(reply.role, 'lead');
    assert.match(reply.text, /add a retry/);
    assert.match(reply.text, /npm run attach/);
  });

  test('a long prompt is truncated rather than echoed whole', () => {
    const reply = demoReply('x'.repeat(400));
    assert.ok(reply.text.length < 400, 'expected the prompt to be shortened');
    assert.ok(reply.text.includes('…'));
  });

  test('an empty prompt still produces a sensible reply', () => {
    assert.match(demoReply('   ').text, /nothing to run/);
  });

  test('a denial says nothing was written; an approval does not claim it ran', () => {
    assert.match(demoDecision('deny'), /nothing was written/i);
    const allowed = demoDecision('allow');
    assert.match(allowed, /allowed/i);
    assert.doesNotMatch(allowed, /^executed/i);
  });
});
