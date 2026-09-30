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
import { OrganizationsService } from './organizations.service.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { RolesGuard } from '../common/guards/roles.guard.js';
import { Roles } from '../common/decorators/roles.decorator.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import type { JwtPayload } from '../auth/interfaces/auth.interfaces.js';
import { UserRole } from '@prisma/client';

@Controller('api/v1/organizations')
@UseGuards(JwtAuthGuard, RolesGuard)
export class OrganizationsController {
  constructor(private readonly organizationsService: OrganizationsService) {}

  @Post()
  @Roles(UserRole.ADMIN)
  @HttpCode(HttpStatus.CREATED)
  async createOrganization(
    @Body() dto: any,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.organizationsService.createOrganization(dto, user.sub, requestId);
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Patch(':id')
  @Roles(UserRole.ADMIN)
  async updateOrganization(
    @Param('id') id: string,
    @Body() dto: any,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.organizationsService.updateOrganization(id, dto, user.sub, requestId);
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Get()
  @Roles(UserRole.ADMIN)
  async findAll() {
    const data = await this.organizationsService.findAllOrganizations();
    return { data, meta: { timestamp: new Date().toISOString() } };
  }

  @Get(':id')
  @Roles(UserRole.ADMIN)
  async findOne(@Param('id') id: string) {
    const data = await this.organizationsService.findOrganizationById(id);
    return { data, meta: { timestamp: new Date().toISOString() } };
  }

  @Post('units')
  @Roles(UserRole.ADMIN)
  @HttpCode(HttpStatus.CREATED)
  async createUnit(@Body() dto: any, @CurrentUser() user: JwtPayload, @Req() req: Request) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.organizationsService.createOrgUnit(dto, user.sub, requestId);
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Patch('units/:id')
  @Roles(UserRole.ADMIN)
  async updateUnit(
    @Param('id') id: string,
    @Body() dto: any,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.organizationsService.updateOrgUnit(id, dto, user.sub, requestId);
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Get(':id/units')
  @Roles(UserRole.ADMIN)
  async findUnits(@Param('id') id: string) {
    const data = await this.organizationsService.findUnitsByOrganization(id);
    return { data, meta: { timestamp: new Date().toISOString() } };
  }

  @Get('units/:id')
  @Roles(UserRole.ADMIN, UserRole.SUPERVISOR)
  async findUnit(@Param('id') id: string) {
    const data = await this.organizationsService.findOrgUnitById(id);
    return { data, meta: { timestamp: new Date().toISOString() } };
  }
}
