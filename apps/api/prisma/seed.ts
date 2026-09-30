import { PrismaClient, UserRole, TestStatus } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { v4 as uuidv4 } from 'uuid';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding FieldSure database...');

  // Create default admin user
  const adminPassword = await bcrypt.hash('Admin@123456', 12);
  const admin = await prisma.user.upsert({
    where: { email: 'admin@fieldsure.local' },
    update: {},
    create: {
      operatorId: 'ADMIN-001',
      name: 'System Administrator',
      email: 'admin@fieldsure.local',
      passwordHash: adminPassword,
      role: UserRole.ADMIN,
    },
  });
  console.log(`  Admin user: ${admin.email} (${admin.id})`);

  // Create demo supervisor
  const supervisorPassword = await bcrypt.hash('Super@123456', 12);
  const supervisor = await prisma.user.upsert({
    where: { email: 'supervisor@fieldsure.local' },
    update: {},
    create: {
      operatorId: 'SUP-001',
      name: 'Demo Supervisor',
      email: 'supervisor@fieldsure.local',
      passwordHash: supervisorPassword,
      role: UserRole.SUPERVISOR,
    },
  });
  console.log(`  Supervisor: ${supervisor.email} (${supervisor.id})`);

  // Create demo operator
  const operatorPassword = await bcrypt.hash('Operator@123456', 12);
  const operator = await prisma.user.upsert({
    where: { email: 'operator@fieldsure.local' },
    update: {},
    create: {
      operatorId: 'OPR-001',
      name: 'Demo Operator',
      email: 'operator@fieldsure.local',
      passwordHash: operatorPassword,
      role: UserRole.OPERATOR,
    },
  });
  console.log(`  Operator: ${operator.email} (${operator.id})`);

  // Create Test Kits
  console.log('Seeding Demo Test Kits...');
  const kit1 = await prisma.testKit.upsert({
    where: { code: 'DEMO-MARQ-01' },
    update: {},
    create: {
      code: 'DEMO-MARQ-01',
      name: 'Marquis Reagent (DEMO)',
      manufacturer: 'FieldSure Simulated Kits',
      description: 'Presumptive test for Amphetamines and Opiates (Simulated for Demo)',
      active: true,
      configurationVersion: 'v1.0.0-demo',
    },
  });

  const kit2 = await prisma.testKit.upsert({
    where: { code: 'DEMO-COBALT-02' },
    update: {},
    create: {
      code: 'DEMO-COBALT-02',
      name: 'Cobalt Thiocyanate (DEMO)',
      manufacturer: 'FieldSure Simulated Kits',
      description: 'Presumptive test for Cocaine (Simulated for Demo)',
      active: true,
      configurationVersion: 'v1.0.0-demo',
    },
  });
  console.log(`  Created test kits: ${kit1.code}, ${kit2.code}`);

  // Create Historical Demo Tests
  console.log('Seeding Demo Test History...');
  
  const createDemoTest = async (testNumber: string, status: TestStatus, result: string | null, confidence: number | null, daysAgo: number) => {
    const id = uuidv4();
    const date = new Date();
    date.setDate(date.getDate() - daysAgo);

    const test = await prisma.test.upsert({
      where: { testNumber },
      update: {},
      create: {
        id,
        testNumber,
        caseId: `CASE-2026-${1000 + daysAgo}`,
        sampleId: `SMP-${testNumber}`,
        operatorId: operator.id,
        kitId: kit1.id,
        status,
        result,
        confidence,
        algorithmVersion: result ? 'DEMO-ALG-1.0' : null,
        configurationVersion: 'v1.0.0-demo',
        clientCreatedAt: date,
        serverCreatedAt: date,
        startedAt: date,
        completedAt: status === TestStatus.COMPLETED ? new Date(date.getTime() + 60000) : null,
      },
    });

    if (result) {
      await prisma.classification.upsert({
        where: { testId: id },
        update: {},
        create: {
          testId: id,
          result: result,
          confidence: confidence ?? 0,
          algorithmVersion: 'DEMO-ALG-1.0',
          modelVersion: 'DEMO-CONFIG-v1',
          configurationVersion: 'v1.0.0-demo',
          createdAt: new Date(date.getTime() + 60000),
        },
      });

      // Create evidence record
      await prisma.evidenceRecord.upsert({
        where: { testId: id },
        update: {},
        create: {
          testId: id,
          schemaVersion: '1.0',
          canonicalizationVersion: '1.0',
          imageHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', // SHA-256 empty string dummy
          recordHash: 'demo-record-hash-12345',
          hashingAlgorithm: 'SHA-256',
          signature: 'demo-cryptographic-signature-abcd1234',
          signatureAlgorithm: 'ECDSA-P256',
          signerKeyId: 'demo-key-01',
          signedAt: new Date(date.getTime() + 65000),
          verificationStatus: 'VERIFIED',
          createdAt: new Date(date.getTime() + 65000),
        },
      });
    }

    return test;
  };

  // 1. Positive Result
  await createDemoTest('FS-2026-000001', TestStatus.COMPLETED, 'POSITIVE', 0.95, 5);
  // 2. Negative Result
  await createDemoTest('FS-2026-000002', TestStatus.COMPLETED, 'NEGATIVE', 0.88, 4);
  // 3. Inconclusive Result
  await createDemoTest('FS-2026-000003', TestStatus.COMPLETED, 'INCONCLUSIVE', 0.35, 3);
  // 4. Pending Sync (simulated offline record that arrived late)
  await createDemoTest('FS-2026-000004', TestStatus.PROCESSING, null, null, 1);

  console.log('Seeding complete.');
}

main()
  .catch((e) => {
    console.error('Seed error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
