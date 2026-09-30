import { Test, TestingModule } from '@nestjs/testing';
import { DatasetService } from './dataset.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { BadRequestException } from '@nestjs/common';
import { GroundTruthState, DatasetSampleStatus } from '@prisma/client';

describe('DatasetService (Stage F Operations)', () => {
  let service: DatasetService;
  let prisma: PrismaService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DatasetService,
        {
          provide: PrismaService,
          useValue: {
            pilotProtocol: { findUnique: vi.fn() },
            datasetSample: { findUnique: vi.fn(), create: vi.fn(), update: vi.fn() },
            pilotSite: { create: vi.fn() },
            pilotEnrollment: { create: vi.fn() },
            datasetSampleCustody: { create: vi.fn() },
            $transaction: vi.fn((operations) => Promise.all(operations)),
          },
        },
      ],
    }).compile();

    service = module.get<DatasetService>(DatasetService);
    prisma = module.get<PrismaService>(PrismaService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('enrollPilotSample (Collection idempotency & Specimen identity)', () => {
    it('should create new dataset sample if no duplicate originalTestId', async () => {
      vi.mocked(prisma.pilotProtocol.findUnique).mockResolvedValue({ id: 'protocol-1', isActive: true } as any);
      vi.mocked(prisma.datasetSample.findUnique).mockResolvedValue(null);
      vi.mocked(prisma.datasetSample.create).mockResolvedValue({ id: 'sample-1' } as any);

      const result = await service.enrollPilotSample('user-1', 'v1', 'test-1', 'KIT-A', 'hash123', {});
      expect(result).toEqual({ id: 'sample-1' });
      expect(prisma.datasetSample.create).toHaveBeenCalled();
    });

    it('should return existing sample to enforce idempotency (offline sync safety)', async () => {
      vi.mocked(prisma.pilotProtocol.findUnique).mockResolvedValue({ id: 'protocol-1', isActive: true } as any);
      const existing = { id: 'sample-existing', originalTestId: 'test-1' } as any;
      vi.mocked(prisma.datasetSample.findUnique).mockResolvedValue(existing);

      const result = await service.enrollPilotSample('user-1', 'v1', 'test-1', 'KIT-A', 'hash123', {});
      expect(result).toEqual(existing);
      expect(prisma.datasetSample.create).not.toHaveBeenCalled();
    });
  });

  describe('transferCustodyToLab (Laboratory handoff and receipt)', () => {
    it('should record submission and update ground truth state', async () => {
      vi.mocked(prisma.datasetSample.findUnique).mockResolvedValue({ id: 'sample-1' } as any);
      vi.mocked(prisma.datasetSampleCustody.create).mockResolvedValue({} as any);
      vi.mocked(prisma.datasetSample.update).mockResolvedValue({} as any);

      await service.transferCustodyToLab('sample-1', 'user-sender', 'lab-1', 'Good condition');
      
      expect(prisma.datasetSampleCustody.create).toHaveBeenCalledWith({
        data: expect.objectContaining({ action: 'SUBMITTED_TO_LAB' }),
      });
      expect(prisma.datasetSample.update).toHaveBeenCalledWith({
        where: { id: 'sample-1' },
        data: { groundTruthState: GroundTruthState.PENDING_LAB_RESULT },
      });
    });
  });

  describe('receiveAtLab', () => {
    it('should mark received and maintain PENDING_LAB_RESULT status', async () => {
      vi.mocked(prisma.datasetSample.findUnique).mockResolvedValue({ id: 'sample-1', status: DatasetSampleStatus.INGESTED } as any);
      vi.mocked(prisma.datasetSampleCustody.create).mockResolvedValue({} as any);
      vi.mocked(prisma.datasetSample.update).mockResolvedValue({} as any);

      await service.receiveAtLab('sample-1', 'lab-user', 'lab-1', true, 'Intact');

      expect(prisma.datasetSampleCustody.create).toHaveBeenCalledWith({
        data: expect.objectContaining({ action: 'RECEIVED_BY_LAB' }),
      });
      expect(prisma.datasetSample.update).toHaveBeenCalledWith({
        where: { id: 'sample-1' },
        data: expect.objectContaining({ groundTruthState: GroundTruthState.PENDING_LAB_RESULT }),
      });
    });

    it('should mark rejected by lab, updating state to REJECTED and EXCLUDED', async () => {
      vi.mocked(prisma.datasetSample.findUnique).mockResolvedValue({ id: 'sample-1', status: DatasetSampleStatus.INGESTED } as any);
      vi.mocked(prisma.datasetSampleCustody.create).mockResolvedValue({} as any);
      vi.mocked(prisma.datasetSample.update).mockResolvedValue({} as any);

      await service.receiveAtLab('sample-1', 'lab-user', 'lab-1', false, 'Damaged during transit');

      expect(prisma.datasetSampleCustody.create).toHaveBeenCalledWith({
        data: expect.objectContaining({ action: 'REJECTED_BY_LAB' }),
      });
      expect(prisma.datasetSample.update).toHaveBeenCalledWith({
        where: { id: 'sample-1' },
        data: expect.objectContaining({
            groundTruthState: GroundTruthState.REJECTED,
            status: DatasetSampleStatus.EXCLUDED,
        }),
      });
    });
  });

  describe('verifyLabResult (Reviewer authorization and disputes)', () => {
    it('should allow reviewer to verify a lab result', async () => {
      vi.mocked(prisma.datasetSample.findUnique).mockResolvedValue({ id: 'sample-1', groundTruthState: GroundTruthState.LAB_RESULT_RECEIVED } as any);
      vi.mocked(prisma.datasetSample.update).mockResolvedValue({} as any);

      await service.verifyLabResult('reviewer-1', 'sample-1', true);
      
      expect(prisma.datasetSample.update).toHaveBeenCalledWith({
        where: { id: 'sample-1' },
        data: expect.objectContaining({
            reviewerId: 'reviewer-1',
            groundTruthState: GroundTruthState.VERIFIED,
            status: DatasetSampleStatus.ELIGIBLE_FOR_EVALUATION,
        }),
      });
    });

    it('should throw if verifying a sample not in LAB_RESULT_RECEIVED', async () => {
      vi.mocked(prisma.datasetSample.findUnique).mockResolvedValue({ id: 'sample-1', groundTruthState: GroundTruthState.PENDING_LAB_RESULT } as any);
      
      await expect(service.verifyLabResult('reviewer-1', 'sample-1', true)).rejects.toThrow(BadRequestException);
    });
  });
});
