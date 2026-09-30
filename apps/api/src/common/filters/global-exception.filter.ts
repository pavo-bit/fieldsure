import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  PayloadTooLargeException,
  UnsupportedMediaTypeException,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { ErrorCode } from '../errors/error-codes.js';

/**
 * Global exception filter that sanitizes error responses.
 * Prevents leaking internal details (stack traces, DB errors) to clients.
 * Adds machine-readable error codes and requestId to all error responses.
 */
@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const requestId = request.headers['x-request-id'] as string | undefined;

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let code: string = ErrorCode.INTERNAL_ERROR;
    let message = 'Internal server error';
    let details: unknown = undefined;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const exceptionResponse = exception.getResponse();

      if (typeof exceptionResponse === 'string') {
        message = exceptionResponse;
        code = this.statusToCode(status);
      } else if (typeof exceptionResponse === 'object' && exceptionResponse !== null) {
        const resp = exceptionResponse as Record<string, unknown>;
        
        // If the exception already has a code, use it (AppError)
        if (typeof resp['code'] === 'string') {
          code = resp['code'];
        } else {
          code = this.statusToCode(status);
        }

        message = (resp['message'] as string) ?? message;
        details = resp['errors'] ?? resp['details'];

        // class-validator returns message as array
        if (Array.isArray(resp['message'])) {
          code = ErrorCode.VALIDATION_FAILED;
          message = 'Validation failed';
          details = resp['message'];
        }
      }

      // Map specific exception types
      if (exception instanceof PayloadTooLargeException) {
        code = ErrorCode.PAYLOAD_TOO_LARGE;
        status = 413;
      } else if (exception instanceof UnsupportedMediaTypeException) {
        code = ErrorCode.UNSUPPORTED_MEDIA_TYPE;
        status = 415;
      }
    } else {
      // Log unexpected errors server-side but don't expose details
      console.error(`[${requestId ?? 'NO_REQUEST_ID'}] Unhandled exception:`, exception);
    }

    response.status(status).json({
      error: {
        code,
        message,
        status,
        ...(details ? { details } : {}),
      },
      meta: {
        timestamp: new Date().toISOString(),
        ...(requestId ? { requestId } : {}),
      },
    });
  }

  /**
   * Fallback mapping from HTTP status to error code when no explicit code provided.
   */
  private statusToCode(status: number): string {
    switch (status) {
      case 400: return ErrorCode.VALIDATION_FAILED;
      case 401: return ErrorCode.AUTH_INVALID_CREDENTIALS;
      case 403: return ErrorCode.FORBIDDEN;
      case 404: return ErrorCode.NOT_FOUND;
      case 409: return ErrorCode.CONFLICT;
      case 413: return ErrorCode.PAYLOAD_TOO_LARGE;
      case 415: return ErrorCode.UNSUPPORTED_MEDIA_TYPE;
      case 426: return ErrorCode.APP_VERSION_TOO_OLD;
      case 429: return ErrorCode.RATE_LIMITED;
      case 503: return ErrorCode.ML_UNAVAILABLE;
      default: return ErrorCode.INTERNAL_ERROR;
    }
  }
}
