import { Injectable, ExecutionContext } from '@nestjs/common';
import { ThrottlerGuard } from '@nestjs/throttler';
import type { Request, Response } from 'express';

/**
 * Custom throttler guard that tracks by authenticated user ID (fallback to IP).
 * Adds Retry-After header on 429 responses.
 */
@Injectable()
export class CustomThrottlerGuard extends ThrottlerGuard {
  /**
   * Generate a tracker key based on authenticated user or IP address.
   */
  protected async getTracker(req: Request): Promise<string> {
    // If authenticated, track by user ID
    const user = (req as any).user;
    if (user?.sub) {
      return `user:${user.sub}`;
    }

    // Fallback to IP address for unauthenticated requests
    return req.ip ?? req.socket.remoteAddress ?? 'unknown';
  }
}
