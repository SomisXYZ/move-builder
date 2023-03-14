import { Injectable } from '@nestjs/common';
import * as fs from 'fs';
import { createZodDto } from 'nestjs-zod';

import { z } from 'zod';
import {
  copyFolderRecursive,
  execAsync,
  removeSpace,
  spaceToUnderscore,
} from './utils';

const BASE_PATH = '/tmp/move-builder';

export const BuildModuleInputSchema = z.object({
  collectionName: z.string().min(1).max(50),
  description: z.string().min(0).max(300),
  symbol: z.string().min(0).max(8),
  url: z.string().min(0).max(30),
  royalty: z.number().int().min(0).max(10000),
});

export class BuildModuleInputDto extends createZodDto(BuildModuleInputSchema) {}

@Injectable()
export class AppService {
  constructor() {
    if (!fs.existsSync(BASE_PATH)) {
      fs.mkdirSync(BASE_PATH);
    }
  }

  private async cloneTemplate() {
    const newPath = `${BASE_PATH}/move-project-${Date.now()}`;
    await fs.promises.mkdir(newPath);
    await copyFolderRecursive('./template/', newPath);
    return `${newPath}/template`;
  }

  private async formatToml(path: string, data: BuildModuleInputDto) {
    const filePath = `${path}/Move.toml`;
    const template = await fs.promises.readFile(filePath, 'utf8');

    const formatted = template
      .replace(
        '{{ name_lower_no_space }}',
        spaceToUnderscore(data.collectionName).toLowerCase(),
      )
      .replace('{{ name_no_space }}', removeSpace(data.collectionName));

    await fs.promises.writeFile(filePath, formatted);
  }

  private async formatMove(path: string, data: BuildModuleInputDto) {
    const readFilePath = `${path}/sources/module.move.template`;
    const writeFilePath = `${path}/sources/${removeSpace(
      data.collectionName,
    ).toLowerCase()}.move`;

    const template = await fs.promises.readFile(readFilePath, 'utf8');

    const formatted = template
      .replace(
        '{{ name_lower_no_space }}',
        spaceToUnderscore(data.collectionName).toLowerCase(),
      )
      .replaceAll('{{ name_no_space }}', removeSpace(data.collectionName))
      .replaceAll(
        '{{ name_upper_no_space }}',
        removeSpace(data.collectionName).toUpperCase(),
      )
      .replaceAll('{{ name }}', data.collectionName)
      .replaceAll('{{ description }}', data.description)
      .replaceAll('{{ url }}', data.url)
      .replaceAll('{{ symbol }}', data.symbol)
      .replaceAll('{{ royalty }}', data.royalty.toString());

    await fs.promises.writeFile(writeFilePath, formatted);
  }

  private async formatTemplate(path: string, data: BuildModuleInputDto) {
    await this.formatToml(path, data);
    await this.formatMove(path, data);
  }

  async getSuiVersion() {
    try {
      const { stdout } = await execAsync(`sui --version`, {
        encoding: 'ascii',
      });

      return stdout;
    } catch (err) {
      console.log(err);
    }
  }

  async build(data: BuildModuleInputDto) {
    const path = await this.cloneTemplate();
    await this.formatTemplate(path, data);
    try {
      const { stdout } = await execAsync(
        `sui move build --dump-bytecode-as-base64 --path ${path}`,
        {
          encoding: 'ascii',
        },
      );

      const parsed: string[] = JSON.parse(stdout);
      return parsed[0];
    } catch (err) {
      console.log(err);
    }
  }
}
