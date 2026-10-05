import { Controller, Get } from '@nestjs/common';

@Controller('health')
export class HealthController {
  @Get()
  check() {
    return {
      status: 'ok',
      service: 'civis-italia-api',
      timestamp: new Date().toISOString(),
    };
  }
}
