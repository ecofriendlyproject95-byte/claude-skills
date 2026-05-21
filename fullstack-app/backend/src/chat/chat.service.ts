import { Injectable } from '@nestjs/common';
import Anthropic from '@anthropic-ai/sdk';
import { AgentsService } from '../agents/agents.service';

interface HistoryMessage {
  role: 'user' | 'assistant';
  content: string;
}

@Injectable()
export class ChatService {
  private client: Anthropic;

  constructor(private agentsService: AgentsService) {
    this.client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
  }

  async streamChat(
    agentSlug: string,
    message: string,
    history: HistoryMessage[],
    onChunk: (text: string) => void,
  ): Promise<void> {
    const agent = this.agentsService.findOne(agentSlug);

    const messages = [
      ...history.map((m) => ({ role: m.role, content: m.content })),
      { role: 'user' as const, content: message },
    ];

    const stream = await this.client.messages.stream({
      model: 'claude-sonnet-4-6',
      max_tokens: 4096,
      system: agent.systemPrompt,
      messages,
    });

    for await (const chunk of stream) {
      if (
        chunk.type === 'content_block_delta' &&
        chunk.delta.type === 'text_delta'
      ) {
        onChunk(chunk.delta.text);
      }
    }
  }
}
