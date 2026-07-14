import {constants as fileConstants} from "node:fs";
import {open} from "node:fs/promises";

export const MAX_SOCIAL_CUTOVER_BACKUP_BYTES = 64 * 1_024 * 1_024;

async function readExactBoundedFile(handle, expectedSize) {
  const capacity = Math.min(
    expectedSize + 1,
    MAX_SOCIAL_CUTOVER_BACKUP_BYTES + 1
  );
  const buffer = Buffer.allocUnsafe(capacity);
  let offset = 0;
  while (offset < capacity) {
    const {bytesRead} = await handle.read(
      buffer,
      offset,
      capacity - offset,
      offset
    );
    if (bytesRead === 0) break;
    offset += bytesRead;
  }
  if (offset !== expectedSize) {
    throw new Error("Reviewed backup changed while it was being read.");
  }
  return buffer.subarray(0, offset).toString("utf8");
}

export async function readReviewedBackupFile(path) {
  if (typeof fileConstants.O_NOFOLLOW !== "number") {
    throw new Error("This host cannot safely open a no-follow backup file.");
  }

  let handle;
  try {
    handle = await open(
      path,
      fileConstants.O_RDONLY | fileConstants.O_NOFOLLOW
    );
  } catch {
    throw new Error("Unable to open the reviewed backup without following links.");
  }

  try {
    const metadata = await handle.stat();
    if (!metadata.isFile() || (metadata.mode & 0o7777) !== 0o600) {
      throw new Error(
        "Apply requires a regular backup file with exact mode 0600."
      );
    }
    if (metadata.size < 1 ||
        metadata.size > MAX_SOCIAL_CUTOVER_BACKUP_BYTES) {
      throw new Error(
        `Reviewed backup must be 1–${MAX_SOCIAL_CUTOVER_BACKUP_BYTES} bytes.`
      );
    }

    const contents = await readExactBoundedFile(handle, metadata.size);
    try {
      return JSON.parse(contents);
    } catch {
      throw new Error("Unable to parse the reviewed backup file.");
    }
  } finally {
    await handle.close();
  }
}
