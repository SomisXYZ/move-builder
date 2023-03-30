import { Body, Controller, Get, Post } from '@nestjs/common';
import { AppService, BuildModuleInputDto } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  async healthcheck(): Promise<string> {
    const suiVersion = await this.appService.getSuiVersion();
    return `Service is running ${suiVersion}`;
  }

  @Post('/build')
  async build(@Body() body: BuildModuleInputDto) {
    return await this.appService.build(body);
  }
}
