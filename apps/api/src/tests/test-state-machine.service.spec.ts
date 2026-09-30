import { TestStateMachineService, TransitionActor } from './test-state-machine.service.js';
import { TestStatus } from '@prisma/client';
import { BadRequestException } from '@nestjs/common';
import { describe, it, expect, beforeEach } from 'vitest';

describe('TestStateMachineService', () => {
  let service: TestStateMachineService;

  beforeEach(() => {
    service = new TestStateMachineService();
  });

  describe('valid transitions', () => {
    it('should allow DRAFT to CAPTURED', () => {
      expect(() =>
        service.validateTransition(TestStatus.DRAFT, TestStatus.CAPTURED, TransitionActor.SYSTEM),
      ).not.toThrow();
    });

    it('should allow CAPTURED to UPLOADING', () => {
      expect(() =>
        service.validateTransition(TestStatus.CAPTURED, TestStatus.UPLOADING, TransitionActor.SYSTEM),
      ).not.toThrow();
    });

    it('should allow UPLOADING to PENDING_SYNC', () => {
      expect(() =>
        service.validateTransition(TestStatus.UPLOADING, TestStatus.PENDING_SYNC, TransitionActor.SYSTEM),
      ).not.toThrow();
    });

    it('should allow PENDING_SYNC to CAPTURED', () => {
      expect(() =>
        service.validateTransition(TestStatus.PENDING_SYNC, TestStatus.CAPTURED, TransitionActor.SYSTEM),
      ).not.toThrow();
    });

    it('should allow FAILED to DRAFT (retry)', () => {
      expect(() =>
        service.validateTransition(TestStatus.FAILED, TestStatus.DRAFT, TransitionActor.SYSTEM),
      ).not.toThrow();
    });

    it('should allow no-op transitions (e.g. DRAFT to DRAFT)', () => {
      expect(() =>
        service.validateTransition(TestStatus.DRAFT, TestStatus.DRAFT, TransitionActor.SYSTEM),
      ).not.toThrow();
    });
  });

  describe('invalid transitions', () => {
    it('should reject DRAFT to COMPLETED', () => {
      expect(() =>
        service.validateTransition(TestStatus.DRAFT, TestStatus.COMPLETED, TransitionActor.SYSTEM),
      ).toThrow('Invalid status transition');
    });

    it('should reject terminal state COMPLETED to anything', () => {
      expect(() =>
        service.validateTransition(TestStatus.COMPLETED, TestStatus.UPLOADING, TransitionActor.SYSTEM),
      ).toThrow('Invalid status transition');
    });

    it('should reject terminal state INCONCLUSIVE to anything', () => {
      expect(() =>
        service.validateTransition(TestStatus.INCONCLUSIVE, TestStatus.DRAFT, TransitionActor.SYSTEM),
      ).toThrow('Invalid status transition');
    });
  });

  describe('isTerminal', () => {
    it('should return true for COMPLETED', () => {
      expect(service.isTerminal(TestStatus.COMPLETED)).toBe(true);
    });

    it('should return true for INCONCLUSIVE', () => {
      expect(service.isTerminal(TestStatus.INCONCLUSIVE)).toBe(true);
    });

    it('should return false for other states', () => {
      expect(service.isTerminal(TestStatus.DRAFT)).toBe(false);
      expect(service.isTerminal(TestStatus.PROCESSING)).toBe(false);
      expect(service.isTerminal(TestStatus.FAILED)).toBe(false);
    });
  });
});
