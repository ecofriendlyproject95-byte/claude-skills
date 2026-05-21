import { Injectable, NotFoundException } from '@nestjs/common';
import { AGENTS_CATALOG, Agent } from './agents.catalog';

@Injectable()
export class AgentsService {
  listAll(): Omit<Agent, 'systemPrompt'>[] {
    return AGENTS_CATALOG.map(({ systemPrompt, ...rest }) => rest);
  }

  findOne(slug: string): Agent {
    const agent = AGENTS_CATALOG.find((a) => a.slug === slug);
    if (!agent) throw new NotFoundException(`Agent "${slug}" not found`);
    return agent;
  }
}
