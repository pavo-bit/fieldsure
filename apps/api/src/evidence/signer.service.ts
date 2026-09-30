import { Injectable } from '@nestjs/common';
import * as crypto from 'crypto';

@Injectable()
export class SignerService {
  private privateKey: string;
  private publicKey: string;
  public readonly keyId = 'dev-key-1';
  public readonly algorithm = 'RSA-SHA256';

  constructor() {
    // For development, generate a keypair on startup if none is provided via env
    if (process.env.EVIDENCE_PRIVATE_KEY && process.env.EVIDENCE_PUBLIC_KEY) {
      this.privateKey = process.env.EVIDENCE_PRIVATE_KEY;
      this.publicKey = process.env.EVIDENCE_PUBLIC_KEY;
    } else {
      const { privateKey, publicKey } = crypto.generateKeyPairSync('rsa', {
        modulusLength: 2048,
        publicKeyEncoding: { type: 'spki', format: 'pem' },
        privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
      });
      this.privateKey = privateKey;
      this.publicKey = publicKey;
    }
  }

  sign(data: string): string {
    const signer = crypto.createSign(this.algorithm);
    signer.update(data);
    signer.end();
    return signer.sign(this.privateKey, 'base64');
  }

  verify(data: string, signature: string): boolean {
    try {
      const verifier = crypto.createVerify(this.algorithm);
      verifier.update(data);
      verifier.end();
      return verifier.verify(this.publicKey, signature, 'base64');
    } catch {
      return false;
    }
  }
}
