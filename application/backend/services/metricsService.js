const logger = require('../utils/logger');

class MetricsService {
  constructor() {
    this.startTime = Date.now();
    this.requestCount = 0;
    this.authAttempts = 0;
    this.securityEvents = [];
  }

  /**
   * Increment request counter
   */
  incrementRequestCount() {
    this.requestCount++;
  }

  /**
   * Increment auth attempts
   */
  incrementAuthAttempts() {
    this.authAttempts++;
  }

  /**
   * Log security event
   */
  logSecurityEvent(event) {
    const securityEvent = {
      timestamp: new Date().toISOString(),
      ...event
    };
    
    this.securityEvents.push(securityEvent);
    
    // Keep only last 100 events in memory
    if (this.securityEvents.length > 100) {
      this.securityEvents.shift();
    }
    
    logger.info('Security event recorded', securityEvent);
  }

  /**
   * Get application monitoring data
   */
  async getMonitoringData() {
    const uptime = Date.now() - this.startTime;
    
    return {
      application: {
        uptime: Math.floor(uptime / 1000), // seconds
        requestCount: this.requestCount,
        authAttempts: this.authAttempts,
        memoryUsage: process.memoryUsage(),
        nodeVersion: process.version,
        status: 'healthy'
      },
      security: {
        recentEvents: this.securityEvents.slice(-10), // Last 10 events
        totalEvents: this.securityEvents.length,
        threatLevel: this.calculateThreatLevel()
      },
      performance: {
        cpuUsage: process.cpuUsage(),
        loadAverage: process.platform === 'linux' ? require('os').loadavg() : [0, 0, 0],
        freeMemory: require('os').freemem(),
        totalMemory: require('os').totalmem()
      },
      timestamp: new Date().toISOString()
    };
  }

  /**
   * Calculate threat level based on recent security events
   */
  calculateThreatLevel() {
    const recentEvents = this.securityEvents.filter(event => {
      const eventTime = new Date(event.timestamp);
      const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
      return eventTime > oneHourAgo;
    });

    if (recentEvents.length === 0) return 'low';
    if (recentEvents.length < 5) return 'medium';
    return 'high';
  }

  /**
   * Get Zero Trust compliance metrics
   */
  async getZeroTrustMetrics() {
    return {
      authentication: {
        enabled: true,
        mfaEnforced: true,
        tokenValidation: 'cognito-jwt'
      },
      authorization: {
        rbacEnabled: true,
        leastPrivilege: true,
        contextualAccess: true
      },
      network: {
        microSegmentation: true,
        privateLinks: true,
        encryptedTransit: true
      },
      monitoring: {
        flowLogsEnabled: true,
        guardDutyEnabled: true,
        auditLoggingEnabled: true
      },
      score: this.calculateZeroTrustScore()
    };
  }

  /**
   * Calculate Zero Trust maturity score
   */
  calculateZeroTrustScore() {
    // Simplified scoring - in production, this would be more sophisticated
    const metrics = {
      identityVerification: 100, // Cognito JWT
      deviceTrust: 80,           // Basic device validation
      networkSecurity: 95,       // VPC + PrivateLink
      dataProtection: 90,        // Encryption at rest/transit
      analytics: 85              // CloudWatch + GuardDuty
    };

    const average = Object.values(metrics).reduce((a, b) => a + b, 0) / Object.keys(metrics).length;
    return Math.round(average);
  }

  /**
   * Generate synthetic test data for demo purposes
   */
  generateTestData() {
    const testEvents = [
      {
        type: 'authentication_success',
        user: 'test-user@example.com',
        ip: '10.0.10.15',
        message: 'User successfully authenticated'
      },
      {
        type: 'suspicious_activity',
        ip: '192.168.1.100',
        message: 'Multiple failed authentication attempts'
      },
      {
        type: 'vpc_endpoint_access',
        service: 's3',
        message: 'Application accessed S3 via VPC endpoint'
      },
      {
        type: 'security_group_update',
        resource: 'sg-12345678',
        message: 'Security group rules updated'
      }
    ];

    // Add random test events
    testEvents.forEach(event => {
      this.logSecurityEvent(event);
    });

    logger.info('Test data generated for demonstration');
  }
}

// Create singleton instance
const metricsService = new MetricsService();

// Generate some test data for demonstration
if (process.env.NODE_ENV === 'development') {
  setTimeout(() => {
    metricsService.generateTestData();
  }, 5000);
}

module.exports = metricsService;