import {
  Controller,
  Post,
  Get,
  Body,
  UseGuards,
  Req,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import type { Request } from 'express';
import { AuthService } from './auth.service.js';
import { LoginDto, RefreshTokenDto, ChangePasswordDto, LogoutDto } from './dto/auth.dto.js';
import { JwtAuthGuard } from './guards/jwt-auth.guard.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import type { JwtPayload } from './interfaces/auth.interfaces.js';

@Controller('api/v1/auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Post('login')
  @HttpCode(HttpStatus.OK)
  async login(@Body() dto: LoginDto, @Req() req: Request) {
    const ipAddress = req.ip ?? req.socket.remoteAddress;
    const userAgent = req.headers['user-agent'];
    const requestId = req.headers['x-request-id'] as string | undefined;
    const result = await this.authService.login(dto, ipAddress, userAgent, requestId);
    return { data: result, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  async refresh(@Body() dto: RefreshTokenDto, @Req() req: Request) {
    const ipAddress = req.ip ?? req.socket.remoteAddress;
    const userAgent = req.headers['user-agent'];
    const requestId = req.headers['x-request-id'] as string | undefined;
    const result = await this.authService.refresh(
      dto.refreshToken,
      ipAddress,
      userAgent,
      requestId,
    );
    return { data: result, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Post('logout')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  async logout(@CurrentUser() user: JwtPayload, @Body() dto: LogoutDto, @Req() req: Request) {
    const ipAddress = req.ip ?? req.socket.remoteAddress;
    const userAgent = req.headers['user-agent'];
    const requestId = req.headers['x-request-id'] as string | undefined;
    await this.authService.logout(
      user.sub,
      user.sessionId,
      dto.allDevices ?? false,
      ipAddress,
      userAgent,
      requestId,
    );
    return {
      data: { message: 'Logged out successfully' },
      meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) },
    };
  }

  @Post('change-password')
  @UseGuards(JwtAuthGuard)
  @HttpCode(HttpStatus.OK)
  async changePassword(
    @CurrentUser() user: JwtPayload,
    @Body() dto: ChangePasswordDto,
    @Req() req: Request,
  ) {
    const ipAddress = req.ip ?? req.socket.remoteAddress;
    const userAgent = req.headers['user-agent'];
    const requestId = req.headers['x-request-id'] as string | undefined;
    await this.authService.changePassword(user.sub, dto, ipAddress, userAgent, requestId);
    return {
      data: { message: 'Password changed successfully. Please log in again.' },
      meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) },
    };
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  async getProfile(@CurrentUser() user: JwtPayload, @Req() req: Request) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const profile = await this.authService.getProfile(user.sub);
    return { data: profile, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }
}
