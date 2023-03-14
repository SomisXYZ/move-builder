import { Body, Controller, Get, Post } from '@nestjs/common';
import { AppService, BuildModuleInputDto } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  getHello(): string {
    return 'OK';
  }

  @Post('/build')
  async build(@Body() body: BuildModuleInputDto): Promise<{ buffer: string }> {
    return { buffer: await this.appService.build(body) };
  }
}
