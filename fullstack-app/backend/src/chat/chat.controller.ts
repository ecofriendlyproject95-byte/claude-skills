import { Controller, Post, Body, Res, HttpCode } from '@nestjs/common';
import { Response } from 'express';
import { ChatService } from './chat.service';

interface ChatDto {
  agentSlug: string;
  message: string;
  history: Array<{ role: 'user' | 'assistant'; content: string }>;
}

@Controller('chat')
export class ChatController {
  constructor(private chatService: ChatService) {}

  @Post()
  @HttpCode(200)
  async chat(@Body() body: ChatDto, @Res() res: Response) {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('Access-Control-Allow-Origin', '*');

    try {
      await this.chatService.streamChat(
        body.agentSlug,
        body.message,
        body.history ?? [],
        (chunk) => {
          res.write(`data: ${JSON.stringify({ text: chunk })}\n\n`);
        },
      );
    } catch (err) {
      res.write(`data: ${JSON.stringify({ error: err.message })}\n\n`);
    } finally {
      res.write('data: [DONE]\n\n');
      res.end();
    }
  }
}
