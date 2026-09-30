import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
  Req,
} from '@nestjs/common';
import type { Request } from 'express';
import { TestKitsService } from './test-kits.service.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { RolesGuard } from '../common/guards/roles.guard.js';
import { Roles } from '../common/decorators/roles.decorator.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import type { JwtPayload } from '../auth/interfaces/auth.interfaces.js';
import { UserRole } from '@prisma/client';

@Controller('api/v1/test-kits')
@UseGuards(JwtAuthGuard, RolesGuard)
export class TestKitsController {
  constructor(private readonly testKitsService: TestKitsService) {}

  @Post()
  @Roles(UserRole.ADMIN)
  @HttpCode(HttpStatus.CREATED)
  async createKit(@Body() dto: any, @CurrentUser() user: JwtPayload, @Req() req: Request) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.testKitsService.createKit(dto, user.sub, requestId);
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Patch(':id')
  @Roles(UserRole.ADMIN)
  async updateKit(
    @Param('id') id: string,
    @Body() dto: any,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.testKitsService.updateKit(id, dto, user.sub, requestId);
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Delete(':id')
  @Roles(UserRole.ADMIN)
  @HttpCode(HttpStatus.OK)
  async deactivateKit(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.testKitsService.deactivateKit(id, user.sub, requestId);
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Get()
  async findAll() {
    const data = await this.testKitsService.findAllKits();
    return { data, meta: { timestamp: new Date().toISOString() } };
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    const data = await this.testKitsService.findKitById(id);
    return { data, meta: { timestamp: new Date().toISOString() } };
  }

  @Post(':id/versions')
  @Roles(UserRole.ADMIN)
  @HttpCode(HttpStatus.CREATED)
  async createVersion(
    @Param('id') id: string,
    @Body() dto: any,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.testKitsService.createKitVersion(
      { ...dto, kitId: id },
      user.sub,
      requestId,
    );
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Get(':id/versions')
  async findVersions(@Param('id') id: string) {
    const data = await this.testKitsService.findVersionsByKit(id);
    return { data, meta: { timestamp: new Date().toISOString() } };
  }
}
