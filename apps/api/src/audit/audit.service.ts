import { Injectable } from '@nestjs/common';
import { AuditEventType, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service.js';

export interface AuditEntry {
  eventType: AuditEventType;
  userId?: string;
  resourceType?: string;
  resourceId?: string;
  details?: Prisma.InputJsonValue;
  ipAddress?: string;
  userAgent?: string;
  requestId?: string;
}

@Injectable()
export class AuditService {
  constructor(private prisma: PrismaService) {}

  /**
   * Record an audit event. Fire-and-forget — audit failures
   * should not block the primary operation.
   */
  async log(entry: AuditEntry): Promise<void> {
    try {
      await this.prisma.auditLog.create({
        data: {
          eventType: entry.eventType,
          userId: entry.userId,
          resourceType: entry.resourceType,
          resourceId: entry.resourceId,
          details: entry.details ?? undefined,
          ipAddress: entry.ipAddress,
          userAgent: entry.userAgent,
          requestId: entry.requestId,
        },
      });
    } catch (error) {
      // Audit logging must never crash the application.
      // In production, this should go to a secondary logging system.
      console.error('Audit log write failed:', error);
    }
  }
}
