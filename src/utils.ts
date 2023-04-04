import { exec } from 'child_process';
import { promisify } from 'util';
import * as fs from 'fs';
import * as path from 'path';

export const execAsync = promisify(exec);

async function exists(f: string) {
  try {
    await fs.promises.stat(f);
    return true;
  } catch {
    return false;
  }
}

async function copyFile(source: string, target: string) {
  let targetFile = target;

  // If target is a directory, a new file with the same name will be created
  if (await exists(target)) {
    if ((await fs.promises.lstat(target)).isDirectory()) {
      targetFile = path.join(target, path.basename(source));
    }
  }

  await fs.promises.writeFile(targetFile, await fs.promises.readFile(source));
}

export async function copyFolderRecursive(source: string, target: string) {
  let files = [];

  // Check if folder needs to be created or integrated
  const targetFolder = path.join(target, path.basename(source));
  if (!(await exists(targetFolder))) {
    fs.mkdirSync(targetFolder);
  }

  // Copy
  if ((await fs.promises.lstat(source)).isDirectory()) {
    files = await fs.promises.readdir(source);
    for (const file of files) {
      const curSource = path.join(source, file);
      if ((await fs.promises.lstat(curSource)).isDirectory()) {
        await copyFolderRecursive(curSource, targetFolder);
      } else {
        await copyFile(curSource, targetFolder);
      }
    }
  }
}

export function spaceToUnderscore(str: string) {
  return str.replaceAll(' ', '_');
}

export function removeSpace(str: string) {
  return str.replaceAll(' ', '');
}
