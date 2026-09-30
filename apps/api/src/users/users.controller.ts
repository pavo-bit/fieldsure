import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
  Req,
} from '@nestjs/common';
import type { Request } from 'express';
import { UserRole } from '@prisma/client';
import { UsersService } from './users.service.js';
import { CreateUserDto, UpdateUserDto, QueryUsersDto } from './dto/user.dto.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { RolesGuard } from '../common/guards/roles.guard.js';
import { Roles } from '../common/decorators/roles.decorator.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import type { JwtPayload } from '../auth/interfaces/auth.interfaces.js';

@Controller('api/v1/users')
@UseGuards(JwtAuthGuard, RolesGuard)
export class UsersController {
  constructor(private usersService: UsersService) {}

  @Post()
  @Roles(UserRole.ADMIN)
  async create(@Body() dto: CreateUserDto, @CurrentUser() user: JwtPayload, @Req() req: Request) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const result = await this.usersService.create(dto, user.sub, requestId);
    return { data: result, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Get()
  @Roles(UserRole.ADMIN, UserRole.SUPERVISOR)
  async findAll(@Query() query: QueryUsersDto, @Req() req: Request) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const result = await this.usersService.findAll(query);
    return { data: result, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Get(':id')
  @Roles(UserRole.ADMIN, UserRole.SUPERVISOR)
  async findById(@Param('id') id: string, @Req() req: Request) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const result = await this.usersService.findById(id);
    return { data: result, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Patch(':id')
  @Roles(UserRole.ADMIN)
  async update(
    @Param('id') id: string,
    @Body() dto: UpdateUserDto,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const result = await this.usersService.update(id, dto, user.sub, requestId);
    return { data: result, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Delete(':id')
  @Roles(UserRole.ADMIN)
  @HttpCode(HttpStatus.OK)
  async deactivate(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    await this.usersService.deactivate(id, user.sub, requestId);
    return {
      data: { message: 'User deactivated' },
      meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) },
    };
  }
}
