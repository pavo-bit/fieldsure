import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
  Req,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Request } from 'express';
import { TestsService } from './tests.service.js';
import { CreateTestDto, UpdateTestStatusDto, QueryTestsDto } from './dto/test.dto.js';
import { RequestUploadDto, CompleteUploadDto } from './dto/upload.dto.js';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard.js';
import { CurrentUser } from '../common/decorators/current-user.decorator.js';
import type { JwtPayload } from '../auth/interfaces/auth.interfaces.js';

@Controller('api/v1/tests')
@UseGuards(JwtAuthGuard)
export class TestsController {
  constructor(private readonly testsService: TestsService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  async create(@Body() dto: CreateTestDto, @CurrentUser() user: JwtPayload, @Req() req: Request) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.testsService.create(dto, user.sub, requestId);
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Get()
  async findAll(@Query() query: QueryTestsDto, @CurrentUser() user: JwtPayload, @Req() req: Request) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.testsService.findAll(query, user.sub, user.role);
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Get(':id')
  async findOne(@Param('id') id: string, @CurrentUser() user: JwtPayload, @Req() req: Request) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.testsService.findById(id, user.sub, user.role);
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Patch(':id/status')
  async updateStatus(
    @Param('id') id: string,
    @Body() dto: UpdateTestStatusDto,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.testsService.updateStatus(id, dto, user.sub, user.role, requestId);
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  /**
   * Request a presigned upload URL for secure direct-to-storage upload.
   * Server generates the object key and returns time-limited upload URL.
   * REPLACES unsafe imageUrl parameter in /process endpoint.
   */
  @Post(':id/upload-url')
  @HttpCode(HttpStatus.OK)
  async requestUploadUrl(
    @Param('id') id: string,
    @Body() dto: RequestUploadDto,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.testsService.requestUploadUrl(id, dto, user.sub, user.role, requestId);
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  /**
   * Complete upload after client has uploaded to presigned URL.
   * Verifies hash match, creates ImageAsset, and triggers processing.
   */
  @Post(':id/complete-upload')
  @HttpCode(HttpStatus.OK)
  async completeUpload(
    @Param('id') id: string,
    @Body() dto: CompleteUploadDto,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.testsService.completeUpload(id, dto, user.sub, user.role, requestId);
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  /**
   * DEPRECATED: This endpoint accepts arbitrary imageUrl which is an SSRF risk.
   * Use POST /:id/upload-url + POST /:id/complete-upload instead.
   * This will be removed in a future version.
   */
  @Post(':id/process')
  @HttpCode(HttpStatus.OK)
  async processImage(
    @Param('id') id: string,
    @Body() dto: { imageUrl: string },
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.testsService.processImage(id, dto.imageUrl, user.sub, user.role, requestId);
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Get(':id/result')
  async getResult(@Param('id') id: string, @CurrentUser() user: JwtPayload, @Req() req: Request) {
    const requestId = req.headers['x-request-id'] as string | undefined;
    const data = await this.testsService.getResult(id, user.sub, user.role);
    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }

  @Post(':id/image')
  @HttpCode(HttpStatus.CREATED)
  @UseInterceptors(FileInterceptor('image'))
  async uploadImage(
    @Param('id') id: string,
    @UploadedFile() file: any,
    @Body('clientHash') clientHash: string | undefined,
    @Body('captureMetadata') captureMetadataStr: string | undefined,
    @CurrentUser() user: JwtPayload,
    @Req() req: Request,
  ) {
    if (!file) {
      throw new BadRequestException('Image file is required');
    }

    const requestId = req.headers['x-request-id'] as string | undefined;

    // Parse capture metadata if provided
    let captureMetadata: any = null;
    if (captureMetadataStr) {
      try {
        captureMetadata = JSON.parse(captureMetadataStr);
      } catch {
        throw new BadRequestException('Invalid captureMetadata JSON');
      }
    }

    const data = await this.testsService.uploadImage(
      id,
      file.buffer,
      file.mimetype,
      file.originalname,
      clientHash,
      captureMetadata,
      user.sub,
      user.role,
      requestId,
    );

    return { data, meta: { timestamp: new Date().toISOString(), ...(requestId ? { requestId } : {}) } };
  }
}
