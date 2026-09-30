import {
  Controller,
  Get,
  Post,
  Param,
  Body,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
  Req,
  Header,
} from '@nestjs/common';
import type { Request } from 'express';
import { LabConfirmationsService } from './lab-confirmations.service.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { RolesGuard } from '../common/guards/roles.guard.js';
import { Roles } from '../common/decorators/roles.decorator.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import type { JwtPayload } from '../auth/interfaces/auth.interfaces.js';
import { UserRole } from '@prisma/client';

@Controller('api/v1/tests/:testId/lab-confirmation')
@UseGuards(JwtAuthGuard, RolesGuard)
export class LabConfirmationsController {
  constructor(private readonly labConfirmationsService: LabConfirmationsService) {}

  @Post()
  @Roles(UserRole.SUPERVISOR, UserRole.ADMIN, UserRole.LAB_ANALYST)
  @HttpCode(HttpStatus.CREATED)
  async createLabConfirmation(
    @Param('testId') testId: string,
    @Body() dto: any,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.labConfirmationsService.createLabConfirmation(
      { ...dto, testId },
      user.sub,
      user.role,
      requestId,
    );
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Get()
  async findLabConfirmation(@Param('testId') testId: string) {
    const data = await this.labConfirmationsService.findLabConfirmationByTest(testId);
    return { data, meta: { timestamp: new Date().toISOString() } };
  }
}

@Controller('api/v1/lab-confirmations')
@UseGuards(JwtAuthGuard, RolesGuard)
export class LabConfirmationsExportController {
  constructor(private readonly labConfirmationsService: LabConfirmationsService) {}

  @Get('export')
  @Roles(UserRole.ADMIN, UserRole.SUPERVISOR)
  @Header('Content-Type', 'text/csv')
  @Header('Content-Disposition', 'attachment; filename="labelled-dataset.csv"')
  async exportDataset(@Query('format') format?: 'csv' | 'jsonl') {
    return this.labConfirmationsService.exportLabelledDataset(format || 'csv');
  }
}
