import { Injectable, BadRequestException, UnauthorizedException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { GroundTruthState, DatasetSampleStatus } from '@prisma/client';

@Injectable()
export class DatasetService {
  constructor(private readonly prisma: PrismaService) {}

  async enrollPilotSample(
    userId: string,
    protocolVersion: string,
    testId: string,
    kitCode: string,
    imageHash: string,
    metadata: any
  ) {
    const protocol = await this.prisma.pilotProtocol.findUnique({
      where: { protocolVersion },
    });

    if (!protocol || !protocol.isActive) {
      throw new BadRequestException('Invalid or inactive pilot protocol');
    }

    // Idempotent ingestion logic
    const existing = await this.prisma.datasetSample.findUnique({
      where: { originalTestId: testId },
    });

    if (existing) {
      return existing;
    }

    return this.prisma.datasetSample.create({
      data: {
        protocolId: protocol.id,
        datasetVersion: '1.0.0', // Configurable versioning
        originalTestId: testId,
        imageHash,
        kitCode,
        operatorId: userId,
        status: DatasetSampleStatus.INGESTED,
        groundTruthState: GroundTruthState.PENDING_LAB_RESULT,
        ...metadata,
      },
    });
  }

  async submitLabResult(
    labUserId: string,
    sampleId: string,
    labSampleId: string,
    labReportRef: string,
    referenceMethod: string,
    groundTruthValue: number,
    groundTruthUnits: string,
    uncertainty?: number
  ) {
    // Requires specific authorization (RBAC should happen in Controller)
    const sample = await this.prisma.datasetSample.findUnique({ where: { id: sampleId } });
    if (!sample) throw new BadRequestException('Sample not found');
    
    if (sample.groundTruthState === GroundTruthState.VERIFIED) {
        throw new BadRequestException('Cannot overwrite verified lab results without dispute process.');
    }

    return this.prisma.datasetSample.update({
      where: { id: sampleId },
      data: {
        labSampleId,
        labReportRef,
        referenceMethod,
        groundTruthValue,
        groundTruthUnits,
        groundTruthUncertainty: uncertainty,
        groundTruthState: GroundTruthState.LAB_RESULT_RECEIVED,
        status: DatasetSampleStatus.PENDING_VERIFICATION,
        groundTruthTimestamp: new Date(),
      },
    });
  }

  async verifyLabResult(
    reviewerId: string,
    sampleId: string,
    isApproved: boolean,
    rejectionReason?: string
  ) {
    const sample = await this.prisma.datasetSample.findUnique({ where: { id: sampleId } });
    if (!sample) throw new BadRequestException('Sample not found');
    
    if (sample.groundTruthState !== GroundTruthState.LAB_RESULT_RECEIVED && sample.groundTruthState !== GroundTruthState.PENDING_REVIEW) {
        throw new BadRequestException('Sample is not in a verifiable state.');
    }

    if (isApproved) {
        return this.prisma.datasetSample.update({
            where: { id: sampleId },
            data: {
                reviewerId,
                groundTruthState: GroundTruthState.VERIFIED,
                status: DatasetSampleStatus.ELIGIBLE_FOR_EVALUATION,
            },
        });
    } else {
        return this.prisma.datasetSample.update({
            where: { id: sampleId },
            data: {
                reviewerId,
                groundTruthState: GroundTruthState.REJECTED,
                status: DatasetSampleStatus.EXCLUDED,
                exclusionReason: rejectionReason || 'Lab result rejected by reviewer',
            },
        });
    }
  }

  // Pilot Operations
  async registerPilotSite(siteCode: string, name: string) {
    return this.prisma.pilotSite.create({
      data: { siteCode, name }
    });
  }

  async enrollOperator(protocolId: string, userId: string, siteId?: string, role: string = 'PILOT_COLLECTOR') {
    return this.prisma.pilotEnrollment.create({
      data: { protocolId, userId, siteId, role }
    });
  }

  async transferCustodyToLab(
    datasetSampleId: string,
    senderUserId: string,
    labId: string,
    condition: string,
    notes?: string
  ) {
    const sample = await this.prisma.datasetSample.findUnique({ where: { id: datasetSampleId } });
    if (!sample) throw new BadRequestException('Dataset sample not found');

    return this.prisma.$transaction([
      this.prisma.datasetSampleCustody.create({
        data: {
          datasetSampleId,
          userId: senderUserId,
          labId,
          action: 'SUBMITTED_TO_LAB',
          condition,
          notes,
        }
      }),
      this.prisma.datasetSample.update({
        where: { id: datasetSampleId },
        data: { groundTruthState: GroundTruthState.PENDING_LAB_RESULT }
      })
    ]);
  }

  async receiveAtLab(
    datasetSampleId: string,
    receiverUserId: string,
    labId: string,
    isAccepted: boolean,
    condition: string,
    notes?: string
  ) {
    const sample = await this.prisma.datasetSample.findUnique({ where: { id: datasetSampleId } });
    if (!sample) throw new BadRequestException('Dataset sample not found');

    const action = isAccepted ? 'RECEIVED_BY_LAB' : 'REJECTED_BY_LAB';
    const groundTruthState = isAccepted ? GroundTruthState.PENDING_LAB_RESULT : GroundTruthState.REJECTED;

    return this.prisma.$transaction([
      this.prisma.datasetSampleCustody.create({
        data: {
          datasetSampleId,
          userId: receiverUserId,
          labId,
          action,
          condition,
          notes,
        }
      }),
      this.prisma.datasetSample.update({
        where: { id: datasetSampleId },
        data: { 
            groundTruthState,
            status: isAccepted ? sample.status : DatasetSampleStatus.EXCLUDED,
            exclusionReason: isAccepted ? null : 'Rejected by lab upon receipt'
        }
      })
    ]);
  }
}

