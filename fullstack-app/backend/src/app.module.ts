import { Module } from '@nestjs/common';
import { AgentsModule } from './agents/agents.module';
import { ChatModule } from './chat/chat.module';

@Module({
  imports: [AgentsModule, ChatModule],
})
export class AppModule {}
