import {
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
  Req,
} from '@nestjs/common';
import type { Request } from 'express';
import { CasesService } from './cases.service.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { RolesGuard } from '../common/guards/roles.guard.js';
import { Roles } from '../common/decorators/roles.decorator.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import type { JwtPayload } from '../auth/interfaces/auth.interfaces.js';
import { UserRole } from '@prisma/client';

@Controller('api/v1/cases')
@UseGuards(JwtAuthGuard, RolesGuard)
export class CasesController {
  constructor(private readonly casesService: CasesService) {}

  @Post()
  @Roles(UserRole.ADMIN, UserRole.SUPERVISOR)
  @HttpCode(HttpStatus.CREATED)
  async createCase(@Body() dto: any, @CurrentUser() user: JwtPayload, @Req() req: Request) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.casesService.createCase(dto, user.sub, requestId);
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Patch(':id')
  @Roles(UserRole.ADMIN, UserRole.SUPERVISOR)
  async updateCase(
    @Param('id') id: string,
    @Body() dto: any,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.casesService.updateCase(id, dto, user.sub, requestId);
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    const data = await this.casesService.findCaseById(id);
    return { data, meta: { timestamp: new Date().toISOString() } };
  }
}

@Controller('api/v1/samples')
@UseGuards(JwtAuthGuard, RolesGuard)
export class SamplesController {
  constructor(private readonly casesService: CasesService) {}

  @Post()
  @Roles(UserRole.ADMIN, UserRole.SUPERVISOR, UserRole.OPERATOR)
  @HttpCode(HttpStatus.CREATED)
  async createSample(@Body() dto: any, @CurrentUser() user: JwtPayload, @Req() req: Request) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.casesService.createSample(dto, user.sub, requestId);
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Patch(':id')
  @Roles(UserRole.ADMIN, UserRole.SUPERVISOR)
  async updateSample(
    @Param('id') id: string,
    @Body() dto: any,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.casesService.updateSample(id, dto, user.sub, requestId);
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    const data = await this.casesService.findSampleById(id);
    return { data, meta: { timestamp: new Date().toISOString() } };
  }

  @Post(':id/custody-events')
  @Roles(UserRole.ADMIN, UserRole.SUPERVISOR, UserRole.OPERATOR)
  @HttpCode(HttpStatus.CREATED)
  async recordCustodyEvent(
    @Param('id') id: string,
    @Body() dto: any,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.casesService.recordCustodyEvent(
      { ...dto, sampleId: id },
      user.sub,
      requestId,
    );
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Get(':id/custody-events')
  async findCustodyEvents(@Param('id') id: string) {
    const data = await this.casesService.findCustodyEventsBySample(id);
    return { data, meta: { timestamp: new Date().toISOString() } };
  }
}
