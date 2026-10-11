import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, test } from 'node:test';

import {
  appDirCandidates,
  attachEnv,
  DEFAULT_API_PORT,
  DEFAULT_UI_PORT,
  findAppExecutable,
  parseAttachArgs,
  toPort,
} from '../scripts/attach.mjs';

describe('attach arguments', () => {
  test('defaults to the two ports the shell itself falls back to', () => {
    const options = parseAttachArgs([]);
    assert.equal(options.uiPort, DEFAULT_UI_PORT);
    assert.equal(options.apiPort, DEFAULT_API_PORT);
    assert.equal(options.app, null);
    assert.equal(options.printEnv, false);
  });

  test('honours overrides and resists nonsense', () => {
    const options = parseAttachArgs(['--ui-port', '6001', '--api-port', '6002', '--print-env']);
    assert.equal(options.uiPort, 6001);
    assert.equal(options.apiPort, 6002);
    assert.equal(options.printEnv, true);

    for (const bad of ['0', '-1', '70000', 'yes', '5174.5']) {
      assert.throws(() => toPort(bad, '--ui-port'), /--ui-port must be a port number/);
    }
    assert.throws(() => parseAttachArgs(['--nope']), /Unknown option/);
  });
});

describe('finding the installed app', () => {
  test('prefers an explicit directory, then the Windows install locations', () => {
    const candidates = appDirCandidates({ LOCALAPPDATA: 'C:\\Users\\x\\AppData\\Local' }, 'win32');
    assert.deepEqual(candidates, [
      path.join('C:\\Users\\x\\AppData\\Local', 'Programs', '@codebufffreebuff-desktop'),
      path.join('C:\\Users\\x\\AppData\\Local', 'Programs', 'freebuff-desktop'),
      path.join('C:\\Users\\x\\AppData\\Local', 'freebuff-desktop'),
    ]);

    const override = appDirCandidates({ FREEBUFF_DESKTOP_DIR: '/somewhere', LOCALAPPDATA: '/local' }, 'win32');
    assert.equal(override[0], '/somewhere');
    assert.equal(override.length, 4);
  });

  test('returns the executable when it is there, and null when it is not', () => {
    const local = fs.mkdtempSync(path.join(os.tmpdir(), 'skinbuff-app-'));
    const install = path.join(local, 'Programs', '@codebufffreebuff-desktop');
    fs.mkdirSync(install, { recursive: true });
    const exe = path.join(install, 'Freebuff.exe');
    fs.writeFileSync(exe, '');

    try {
      assert.equal(findAppExecutable(null, { LOCALAPPDATA: local }, 'win32'), exe);
      // An explicit directory that holds nothing is not a reason to look elsewhere: the
      // caller named it.
      assert.equal(findAppExecutable(path.join(local, 'elsewhere'), { LOCALAPPDATA: local }, 'win32'), null);
      assert.equal(findAppExecutable(null, { LOCALAPPDATA: path.join(local, 'empty') }, 'win32'), null);
    } finally {
      fs.rmSync(local, { recursive: true, force: true });
    }
  });
});

describe('the environment the shell must see', () => {
  test('turns on the dev-UI seam and pins both ports, leaving the rest alone', () => {
    const env = attachEnv(5174, 8787, { PATH: '/usr/bin', FREEBUFF_DEV_UI: undefined });
    assert.equal(env.FREEBUFF_DEV_UI, '1');
    assert.equal(env.FREEBUFF_DESKTOP_UI_PORT, '5174');
    assert.equal(env.FREEBUFF_DESKTOP_API_PORT, '8787');
    assert.equal(env.PATH, '/usr/bin');
  });
});
