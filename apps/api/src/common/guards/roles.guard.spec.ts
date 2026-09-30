import { describe, it, expect, beforeEach, vi } from 'vitest';
import { ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RolesGuard } from './roles.guard.js';
import { UserRole } from '@prisma/client';

describe('RolesGuard', () => {
  let guard: RolesGuard;
  let reflector: Reflector;

  beforeEach(() => {
    reflector = new Reflector();
    guard = new RolesGuard(reflector);
  });

  const createMockContext = (user?: { role?: UserRole }): ExecutionContext => {
    return {
      getHandler: vi.fn(),
      getClass: vi.fn(),
      switchToHttp: vi.fn().mockReturnValue({
        getRequest: vi.fn().mockReturnValue({ user }),
      }),
    } as unknown as ExecutionContext;
  };

  it('should allow access if no roles are required on route', () => {
    vi.spyOn(reflector, 'getAllAndOverride').mockReturnValue(null);
    const context = createMockContext({ role: UserRole.OPERATOR });

    const canActivate = guard.canActivate(context);
    expect(canActivate).toBe(true);
  });

  it('should allow access if user has the required role', () => {
    vi.spyOn(reflector, 'getAllAndOverride').mockReturnValue([UserRole.ADMIN]);
    const context = createMockContext({ role: UserRole.ADMIN });

    const canActivate = guard.canActivate(context);
    expect(canActivate).toBe(true);
  });

  it('should allow access if user has one of multiple acceptable roles', () => {
    vi.spyOn(reflector, 'getAllAndOverride').mockReturnValue([
      UserRole.ADMIN,
      UserRole.SUPERVISOR,
    ]);
    const context = createMockContext({ role: UserRole.SUPERVISOR });

    const canActivate = guard.canActivate(context);
    expect(canActivate).toBe(true);
  });

  it('should deny access if user does not have the required role', () => {
    vi.spyOn(reflector, 'getAllAndOverride').mockReturnValue([UserRole.ADMIN]);
    const context = createMockContext({ role: UserRole.OPERATOR });

    const canActivate = guard.canActivate(context);
    expect(canActivate).toBe(false);
  });

  it('should deny access if request has no authenticated user', () => {
    vi.spyOn(reflector, 'getAllAndOverride').mockReturnValue([UserRole.OPERATOR]);
    const context = createMockContext(undefined);

    const canActivate = guard.canActivate(context);
    expect(canActivate).toBe(false);
  });
});
