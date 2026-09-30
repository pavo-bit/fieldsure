/**
 * ML Service Client with resilience patterns:
 * - Timeout
 * - Retry with exponential backoff
 * - Circuit breaker
 */

import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface MLProcessRequest {
  test_id: string;
  processing_run_id: string;
  image_url: string;
  config_version: string;
}

export interface MLProcessResponse {
  status: string;
  processing_run_id: string;
  test_id: string;
  quality?: {
    acceptable: boolean;
    issues: string[];
    diagnostics: any;
    assessment?: any; // QualityAssessment
  };
  classification?: {
    observedColor: any;
    colorDistance: number;
    nearestReferenceLabel: string;
    qualityStatus: string;
    qualityIssues: string[];
    algorithmVersion: string;
    modelVersion: string;
    configurationVersion: string;
    kitCode: string;
    validationStatus: string;
    features: any;
    uncertainty?: any; // MeasurementUncertainty
    diagnostics: any;
    classifiedAt: string;
    // DEPRECATED fields
    pipelineId?: string;
    result?: string;
    confidence?: number;
  };
  message?: string;
  diagnostics?: any;
}

enum CircuitState {
  CLOSED = 'CLOSED',
  OPEN = 'OPEN',
  HALF_OPEN = 'HALF_OPEN',
}

@Injectable()
export class MLClientService {
  private readonly logger = new Logger(MLClientService.name);
  private readonly mlServiceUrl: string;
  private readonly sharedSecret: string | undefined;
  private readonly timeout: number = 30000; // 30s
  private readonly maxRetries: number = 3;

  // Circuit breaker state
  private circuitState: CircuitState = CircuitState.CLOSED;
  private failureCount: number = 0;
  private lastFailureTime: number = 0;
  private readonly failureThreshold: number = 5;
  private readonly circuitResetTimeout: number = 60000; // 60s

  constructor(private readonly config: ConfigService) {
    this.mlServiceUrl = this.config.get<string>('ML_SERVICE_URL') || 'http://localhost:8000';
    this.sharedSecret = this.config.get<string>('ML_SHARED_SECRET');
    
    if (!this.sharedSecret) {
      this.logger.warn('ML_SHARED_SECRET not configured - requests will fail in production');
    }
  }

  /**
   * Process image through ML service with resilience.
   */
  async processImage(request: MLProcessRequest): Promise<MLProcessResponse> {
    // Check circuit breaker
    if (this.circuitState === CircuitState.OPEN) {
      const now = Date.now();
      if (now - this.lastFailureTime > this.circuitResetTimeout) {
        this.logger.log('Circuit breaker transitioning to HALF_OPEN');
        this.circuitState = CircuitState.HALF_OPEN;
      } else {
        throw new Error('ML_SERVICE_UNAVAILABLE: Circuit breaker is OPEN');
      }
    }

    // Retry with exponential backoff
    let lastError: Error | null = null;
    for (let attempt = 0; attempt < this.maxRetries; attempt++) {
      try {
        const result = await this.makeRequest(request);
        
        // Success - reset circuit breaker
        if (this.circuitState === CircuitState.HALF_OPEN) {
          this.logger.log('Circuit breaker transitioning to CLOSED');
          this.circuitState = CircuitState.CLOSED;
          this.failureCount = 0;
        }
        
        return result;
      } catch (error: any) {
        lastError = error as Error;
        this.logger.warn(
          `ML service request failed (attempt ${attempt + 1}/${this.maxRetries}): ${error.message}`
        );

        // Don't retry on 4xx errors (except 429)
        if (this.isClientError(error) && !this.isRateLimitError(error)) {
          throw error;
        }

        // Wait before retry (exponential backoff with jitter)
        if (attempt < this.maxRetries - 1) {
          const backoffMs = Math.min(1000 * Math.pow(2, attempt), 10000);
          const jitter = Math.random() * 0.3 * backoffMs;
          await this.sleep(backoffMs + jitter);
        }
      }
    }

    // All retries failed - update circuit breaker
    this.recordFailure();
    throw new Error(`ML_SERVICE_UNAVAILABLE: ${lastError?.message || 'Unknown error'}`);
  }

  /**
   * Make HTTP request to ML service with timeout.
   */
  private async makeRequest(request: MLProcessRequest): Promise<MLProcessResponse> {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), this.timeout);

    try {
      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
      };

      // Add authentication if configured
      if (this.sharedSecret) {
        headers['Authorization'] = `Bearer ${this.sharedSecret}`;
      }

      const response = await fetch(`${this.mlServiceUrl}/process`, {
        method: 'POST',
        headers,
        body: JSON.stringify(request),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        // Check for rate limiting
        if (response.status === 429) {
          const retryAfter = response.headers.get('Retry-After');
          throw new Error(`RATE_LIMITED: Retry after ${retryAfter || 'unknown'}`);
        }

        const errorBody = await response.json().catch(() => ({}));
        throw new Error(
          `ML_REQUEST_FAILED: ${response.status} ${errorBody.message || response.statusText}`
        );
      }

      return await response.json();
    } catch (error: any) {
      clearTimeout(timeoutId);

      if (error.name === 'AbortError') {
        throw new Error('ML_TIMEOUT: Request exceeded timeout');
      }

      throw error;
    }
  }

  /**
   * Record failure and update circuit breaker state.
   */
  private recordFailure(): void {
    this.failureCount++;
    this.lastFailureTime = Date.now();

    if (this.failureCount >= this.failureThreshold) {
      this.logger.error('Circuit breaker opening due to repeated failures');
      this.circuitState = CircuitState.OPEN;
    }
  }

  /**
   * Check if error is a client error (4xx).
   */
  private isClientError(error: any): boolean {
    const message = error.message || '';
    return message.includes('ML_REQUEST_FAILED: 4');
  }

  /**
   * Check if error is rate limit (429).
   */
  private isRateLimitError(error: any): boolean {
    const message = error.message || '';
    return message.includes('RATE_LIMITED') || message.includes('429');
  }

  /**
   * Sleep utility for backoff.
   */
  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  /**
   * Get circuit breaker status (for monitoring).
   */
  getCircuitStatus(): { state: CircuitState; failureCount: number } {
    return {
      state: this.circuitState,
      failureCount: this.failureCount,
    };
  }
}
