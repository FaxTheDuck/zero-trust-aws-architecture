const logger = require('../utils/logger');

/**
 * Middleware to validate requests for security threats
 * Implements Zero Trust principle: Never trust, always verify
 */
const validateRequest = (req, res, next) => {
  // Check for basic security headers
  const userAgent = req.get('User-Agent');
  const contentType = req.get('Content-Type');
  
  // Block requests without User-Agent (likely bots/scripts)
  if (!userAgent) {
    logger.warn('Request blocked - no User-Agent header', {
      ip: req.ip,
      path: req.path
    });
    return res.status(400).json({
      success: false,
      error: 'User-Agent header required'
    });
  }

  // Block suspicious User-Agent strings
  const suspiciousPatterns = [
    /sqlmap/i,
    /nikto/i,
    /nmap/i,
    /masscan/i,
    /curl.*python/i
  ];

  if (suspiciousPatterns.some(pattern => pattern.test(userAgent))) {
    logger.warn('Request blocked - suspicious User-Agent', {
      userAgent,
      ip: req.ip,
      path: req.path
    });
    return res.status(403).json({
      success: false,
      error: 'Request blocked'
    });
  }

  // Validate Content-Type for POST/PUT requests
  if (['POST', 'PUT', 'PATCH'].includes(req.method)) {
    if (contentType && !contentType.includes('application/json')) {
      logger.warn('Request blocked - invalid Content-Type', {
        contentType,
        method: req.method,
        ip: req.ip,
        path: req.path
      });
      return res.status(400).json({
        success: false,
        error: 'Content-Type must be application/json'
      });
    }
  }

  // Check for path traversal attempts
  if (req.path.includes('..') || req.path.includes('//')) {
    logger.warn('Request blocked - path traversal attempt', {
      path: req.path,
      ip: req.ip
    });
    return res.status(400).json({
      success: false,
      error: 'Invalid path'
    });
  }

  next();
};

/**
 * Middleware to log security events
 */
const logSecurityEvents = (req, res, next) => {
  // Log all authentication attempts
  if (req.headers.authorization) {
    logger.info('Authentication attempt', {
      ip: req.ip,
      path: req.path,
      method: req.method,
      userAgent: req.get('User-Agent')
    });
  }

  // Log admin endpoint access
  if (req.path.includes('/admin')) {
    logger.info('Admin endpoint access', {
      ip: req.ip,
      path: req.path,
      method: req.method,
      userAgent: req.get('User-Agent')
    });
  }

  next();
};

/**
 * Middleware to add security headers
 */
const addSecurityHeaders = (req, res, next) => {
  // Prevent MIME type sniffing
  res.setHeader('X-Content-Type-Options', 'nosniff');
  
  // Prevent clickjacking
  res.setHeader('X-Frame-Options', 'DENY');
  
  // Enable XSS protection
  res.setHeader('X-XSS-Protection', '1; mode=block');
  
  // Referrer policy
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  
  next();
};

module.exports = {
  validateRequest,
  logSecurityEvents,
  addSecurityHeaders
};