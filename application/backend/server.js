const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const logger = require('./utils/logger');
const authMiddleware = require('./middleware/auth');
const securityMiddleware = require('./middleware/security');
const awsService = require('./services/awsService');
const metricsService = require('./services/metricsService');

const app = express();
const PORT = process.env.PORT || 8080;

// Trust proxy for proper IP detection behind ALB
app.set('trust proxy', 1);

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'", "https://cdn.jsdelivr.net"],
      scriptSrc: ["'self'", "https://cdn.jsdelivr.net"],
      imgSrc: ["'self'", "data:", "https:"],
      connectSrc: ["'self'", process.env.AWS_REGION ? `https://*.${process.env.AWS_REGION}.amazonaws.com` : "'self'"]
    }
  }
}));

// Rate limiting - Zero Trust principle: Don't trust, verify and limit
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// CORS configuration - restrictive by default
const corsOptions = {
  origin: process.env.ALLOWED_ORIGINS ? process.env.ALLOWED_ORIGINS.split(',') : ['http://localhost:3000'],
  credentials: true,
  optionsSuccessStatus: 200
};
app.use(cors(corsOptions));

// Other middleware
app.use(compression());
app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) } }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Security headers and request validation
app.use(securityMiddleware.validateRequest);
app.use(securityMiddleware.logSecurityEvents);

// Health check endpoint (no auth required)
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || '1.0.0',
    environment: process.env.NODE_ENV || 'development'
  });
});

// Zero Trust status endpoint
app.get('/api/zero-trust-status', async (req, res) => {
  try {
    const status = await awsService.getZeroTrustStatus();
    res.json({
      success: true,
      data: status,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('Error getting Zero Trust status:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error'
    });
  }
});

// Protected routes - require authentication
app.use('/api/protected', authMiddleware.verifyToken);

// Dashboard data endpoint
app.get('/api/protected/dashboard', async (req, res) => {
  try {
    const user = req.user;
    logger.info(`Dashboard accessed by user: ${user.sub}`);

    const dashboardData = {
      user: {
        id: user.sub,
        email: user.email,
        role: user['custom:role'] || 'user'
      },
      security: await awsService.getSecurityMetrics(),
      network: await awsService.getNetworkMetrics(),
      monitoring: await metricsService.getMonitoringData(),
      timestamp: new Date().toISOString()
    };

    // Log access for audit trail
    await awsService.logSecurityEvent({
      event: 'DASHBOARD_ACCESS',
      user: user.sub,
      ip: req.ip,
      userAgent: req.get('User-Agent'),
      timestamp: new Date().toISOString()
    });

    res.json({
      success: true,
      data: dashboardData
    });
  } catch (error) {
    logger.error('Error getting dashboard data:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to load dashboard data'
    });
  }
});

// VPC Flow Logs analysis endpoint
app.get('/api/protected/flow-logs', authMiddleware.requireRole('admin'), async (req, res) => {
  try {
    const { timeRange = '1h', limit = 100 } = req.query;
    const flowLogs = await awsService.getFlowLogsAnalysis(timeRange, limit);

    res.json({
      success: true,
      data: flowLogs,
      metadata: {
        timeRange,
        limit,
        generatedAt: new Date().toISOString()
      }
    });
  } catch (error) {
    logger.error('Error getting flow logs:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve flow logs'
    });
  }
});

// GuardDuty findings endpoint
app.get('/api/protected/security-findings', authMiddleware.requireRole('admin'), async (req, res) => {
  try {
    const findings = await awsService.getGuardDutyFindings();

    res.json({
      success: true,
      data: findings,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('Error getting security findings:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve security findings'
    });
  }
});

// Network topology endpoint
app.get('/api/protected/network-topology', async (req, res) => {
  try {
    const topology = await awsService.getNetworkTopology();

    res.json({
      success: true,
      data: topology,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('Error getting network topology:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve network topology'
    });
  }
});

// Test database connectivity (demonstrates VPC endpoint usage)
app.get('/api/protected/test-connectivity', authMiddleware.requireRole('admin'), async (req, res) => {
  try {
    const tests = await awsService.runConnectivityTests();

    res.json({
      success: true,
      data: {
        tests,
        summary: {
          total: tests.length,
          passed: tests.filter(t => t.status === 'success').length,
          failed: tests.filter(t => t.status === 'failed').length
        }
      },
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logger.error('Error running connectivity tests:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to run connectivity tests'
    });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  logger.error('Unhandled error:', error);
  
  // Don't leak error details in production
  const isDevelopment = process.env.NODE_ENV === 'development';
  
  res.status(500).json({
    success: false,
    error: isDevelopment ? error.message : 'Internal server error',
    ...(isDevelopment && { stack: error.stack })
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    error: 'Endpoint not found'
  });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  process.exit(0);
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  logger.info(`🚀 Zero Trust Dashboard Backend started on port ${PORT}`);
  logger.info(`🛡️  Environment: ${process.env.NODE_ENV || 'development'}`);
  logger.info(`🔒 Security features enabled: Helmet, CORS, Rate Limiting`);
  logger.info(`📊 Health check available at: http://localhost:${PORT}/health`);
});

module.exports = app;