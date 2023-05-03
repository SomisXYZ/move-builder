import { Injectable } from '@nestjs/common';
import * as fs from 'fs';
import { createZodDto } from 'nestjs-zod';
import * as _ from 'lodash';

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
  url: z.string().min(0).max(100),
  royalty: z.number().int().min(0).max(10000),
  price: z.number().int().min(0),
  creator: z.string().min(66).max(66),
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
      .replaceAll(
        'module_name',
        spaceToUnderscore(data.collectionName).toLowerCase(),
      )
      .replaceAll('moduleName', removeSpace(data.collectionName));

    await fs.promises.writeFile(filePath, formatted);
  }

  private async formatMove(path: string, data: BuildModuleInputDto) {
    const readFilePath = `${path}/sources/module_name.move`;
    const writeFilePath = `${path}/sources/${spaceToUnderscore(
      data.collectionName,
    ).toLowerCase()}.move`;

    const template = await fs.promises.readFile(readFilePath, 'utf8');

    const formatted = template
      .replaceAll(
        'module_name',
        spaceToUnderscore(data.collectionName).toLowerCase(),
      )
      .replaceAll(
        'MODULE_NAME',
        spaceToUnderscore(data.collectionName).toUpperCase(),
      )
      .replaceAll(
        'ModuleName',
        removeSpace(_.startCase(data.collectionName.toLowerCase())),
      )
      .replaceAll('{{ name }}', data.collectionName)
      .replaceAll('{{ description }}', data.description)
      .replaceAll('{{ url }}', data.url)
      .replaceAll('{{ symbol }}', data.symbol)
      .replaceAll('module_creator_placeholder', data.creator)
      .replaceAll('100', data.royalty.toString())
      .replaceAll('500', data.price.toString());

    await fs.promises.unlink(readFilePath);
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

      const parsed: { modules: string[]; dependencies: string[] } =
        JSON.parse(stdout);
      return parsed;
    } catch (err) {
      console.log(err);
    }
  }
}
