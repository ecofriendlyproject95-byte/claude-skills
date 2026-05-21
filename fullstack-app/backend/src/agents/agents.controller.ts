import { Controller, Get, Param } from '@nestjs/common';
import { AgentsService } from './agents.service';

@Controller('agents')
export class AgentsController {
  constructor(private agentsService: AgentsService) {}

  @Get()
  list() {
    return this.agentsService.listAll();
  }

  @Get(':slug')
  get(@Param('slug') slug: string) {
    return this.agentsService.findOne(slug);
  }
}
