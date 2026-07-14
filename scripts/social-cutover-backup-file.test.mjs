import assert from "node:assert/strict";
import {
  chmod,
  mkdtemp,
  open,
  rm,
  symlink,
  writeFile,
} from "node:fs/promises";
import {tmpdir} from "node:os";
import {join} from "node:path";
import test from "node:test";

import {
  MAX_SOCIAL_CUTOVER_BACKUP_BYTES,
  readReviewedBackupFile,
} from "./social-cutover-backup-file.mjs";

async function withTemporaryDirectory(operation) {
  const directory = await mkdtemp(join(tmpdir(), "noum-social-backup-file-"));
  try {
    await operation(directory);
  } finally {
    await rm(directory, {recursive: true, force: true});
  }
}

test("reviewed backup is parsed through one exact mode-0600 file", async () => {
  await withTemporaryDirectory(async (directory) => {
    const path = join(directory, "backup.json");
    await writeFile(path, '{"schemaVersion":2}\n', {mode: 0o600});
    await chmod(path, 0o600);
    assert.deepEqual(await readReviewedBackupFile(path), {schemaVersion: 2});
  });
});

test("reviewed backup rejects symlinks and permissive files", async () => {
  await withTemporaryDirectory(async (directory) => {
    const target = join(directory, "target.json");
    const link = join(directory, "backup.json");
    await writeFile(target, "{}\n", {mode: 0o600});
    await symlink(target, link);
    await assert.rejects(
      readReviewedBackupFile(link),
      /without following links/
    );

    await rm(link);
    await chmod(target, 0o640);
    await assert.rejects(
      readReviewedBackupFile(target),
      /exact mode 0600/
    );
  });
});

test("reviewed backup rejects an oversized sparse regular file", async () => {
  await withTemporaryDirectory(async (directory) => {
    const path = join(directory, "backup.json");
    const handle = await open(path, "w", 0o600);
    try {
      await handle.truncate(MAX_SOCIAL_CUTOVER_BACKUP_BYTES + 1);
    } finally {
      await handle.close();
    }
    await chmod(path, 0o600);
    await assert.rejects(
      readReviewedBackupFile(path),
      new RegExp(`1–${MAX_SOCIAL_CUTOVER_BACKUP_BYTES} bytes`)
    );
  });
});
