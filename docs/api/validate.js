const fs = require('fs');

try {
  const content = fs.readFileSync('docs/api/openapi.yaml', 'utf8');
  
  // Basic YAML parse check — use JSON-compatible subset validation
  // Check structure without external dependency
  
  // 1. Check file is not empty
  if (!content || content.trim().length === 0) {
    throw new Error('File is empty');
  }
  console.log('File size:', content.length, 'bytes');
  console.log('Line count:', content.split('\n').length);
  
  // 2. Check key structural elements exist
  const checks = [
    ['openapi: 3.0.3', 'OpenAPI version'],
    ['title: FieldSure API', 'API title'],
    ['bearerAuth:', 'Security scheme'],
    ['paths:', 'Paths section'],
    ['components:', 'Components section'],
    ['schemas:', 'Schemas section'],
    ['/api/v1/auth/login:', 'Auth login path'],
    ['/api/v1/auth/refresh:', 'Auth refresh path'],
    ['/api/v1/auth/logout:', 'Auth logout path'],
    ['/api/v1/auth/me:', 'Auth me path'],
    ['/api/v1/users:', 'Users path'],
    ['/api/v1/users/{id}:', 'Users by ID path'],
    ['/api/v1/test-kits:', 'Test kits path'],
    ['/api/v1/test-kits/{id}:', 'Test kits by ID path'],
    ['/api/v1/tests:', 'Tests path'],
    ['/api/v1/tests/{id}:', 'Tests by ID path'],
    ['/api/v1/tests/{id}/status:', 'Tests status path'],
    ['/api/v1/tests/{id}/process:', 'Tests process path'],
    ['/api/v1/tests/{id}/result:', 'Tests result path'],
    ['/api/v1/tests/{id}/evidence:', 'Evidence path'],
    ['/api/v1/tests/{id}/verify:', 'Verify path'],
    ['DEMO-CONFIG-v1', 'Demo config identifier'],
    ['POSITIVE', 'Positive result enum'],
    ['NEGATIVE', 'Negative result enum'],
    ['INCONCLUSIVE', 'Inconclusive result enum'],
    ['SHA-256', 'Hash algorithm'],
    ['RSA-SHA256', 'Signature algorithm'],
  ];
  
  let passed = 0;
  let failed = 0;
  for (const [pattern, name] of checks) {
    if (content.includes(pattern)) {
      passed++;
    } else {
      console.log('MISSING:', name, '(' + pattern + ')');
      failed++;
    }
  }
  
  // 3. Count $ref usages and check they're well-formed
  const refMatches = content.match(/\$ref:\s*'#\/[^']+'/g) || [];
  const refPaths = refMatches.map(r => r.match(/'([^']+)'/)[1]);
  
  // Check each ref target exists as a definition
  let brokenRefs = 0;
  for (const ref of refPaths) {
    const schemaName = ref.split('/').pop();
    if (!content.includes(schemaName + ':')) {
      console.log('POTENTIALLY BROKEN REF:', ref);
      brokenRefs++;
    }
  }
  
  console.log('\n--- Validation Results ---');
  console.log('Structural checks passed:', passed + '/' + checks.length);
  console.log('Structural checks failed:', failed);
  console.log('$ref usages found:', refPaths.length);
  console.log('Potentially broken refs:', brokenRefs);
  
  // Count endpoints
  const endpointLines = content.match(/^\s{4}(get|post|patch|put|delete):/gm) || [];
  console.log('HTTP method declarations:', endpointLines.length);
  
  if (failed === 0 && brokenRefs === 0) {
    console.log('\n✅ VALIDATION PASSED');
  } else {
    console.log('\n❌ VALIDATION ISSUES FOUND');
  }
  
} catch(e) {
  console.error('ERROR:', e.message);
  process.exit(1);
}
