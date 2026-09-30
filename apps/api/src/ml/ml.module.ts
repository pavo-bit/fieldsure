import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { MLClientService } from './ml-client.service.js';

@Module({
  imports: [ConfigModule],
  providers: [MLClientService],
  exports: [MLClientService],
})
export class MLModule {}
