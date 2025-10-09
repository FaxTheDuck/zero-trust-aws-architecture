const { CognitoJwtVerifier } = require('aws-jwt-verify');
const logger = require('../utils/logger');

// Configure Cognito JWT Verifier
const verifier = CognitoJwtVerifier.create({
  userPoolId: process.env.COGNITO_USER_POOL_ID,
  tokenUse: "access",
  clientId: process.env.COGNITO_CLIENT_ID,
});

/**
 * Middleware to verify Cognito JWT token
 * Implements Zero Trust principle: Never trust, always verify
 */
const verifyToken = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error: 'Authorization token required'
      });
    }

    const token = authHeader.substring(7); // Remove 'Bearer ' prefix

    // Verify JWT token with Cognito
    const payload = await verifier.verify(token);
    
    // Add user info to request object
    req.user = payload;
    req.userId = payload.sub;
    req.userRole = payload['custom:role'] || 'user';

    // Log authentication event for audit trail
    logger.info('User authenticated successfully', {
      userId: payload.sub,
      email: payload.email,
      role: payload['custom:role'],
      ip: req.ip,
      userAgent: req.get('User-Agent')
    });

    next();
  } catch (error) {
    logger.warn('Authentication failed', {
      error: error.message,
      ip: req.ip,
      userAgent: req.get('User-Agent')
    });

    return res.status(401).json({
      success: false,
      error: 'Invalid or expired token'
    });
  }
};

/**
 * Middleware to require specific role
 * Implements Zero Trust principle: Least privilege access
 */
const requireRole = (requiredRole) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required'
      });
    }

    const userRole = req.user['custom:role'] || 'user';
    
    // Role hierarchy: admin > user
    const roleHierarchy = {
      'user': 1,
      'admin': 2
    };

    const userRoleLevel = roleHierarchy[userRole] || 0;
    const requiredRoleLevel = roleHierarchy[requiredRole] || 0;

    if (userRoleLevel < requiredRoleLevel) {
      logger.warn('Access denied - insufficient role', {
        userId: req.user.sub,
        userRole,
        requiredRole,
        ip: req.ip
      });

      return res.status(403).json({
        success: false,
        error: 'Insufficient permissions'
      });
    }

    logger.info('Role-based access granted', {
      userId: req.user.sub,
      userRole,
      requiredRole,
      endpoint: req.path
    });

    next();
  };
};

/**
 * Middleware to validate IP address against allowed ranges
 * Additional Zero Trust security layer
 */
const validateIPAddress = (req, res, next) => {
  const clientIP = req.ip;
  const allowedRanges = process.env.ALLOWED_IP_RANGES ? 
    process.env.ALLOWED_IP_RANGES.split(',') : [];

  // Skip IP validation if no ranges specified (development mode)
  if (allowedRanges.length === 0) {
    return next();
  }

  // Simple IP range validation (in production, use proper CIDR validation)
  const isAllowed = allowedRanges.some(range => {
    if (range.includes('/')) {
      // CIDR range - simplified validation
      return clientIP.startsWith(range.split('/')[0].substring(0, 7));
    } else {
      // Exact IP match
      return clientIP === range;
    }
  });

  if (!isAllowed) {
    logger.warn('Access denied - IP not in allowed range', {
      clientIP,
      allowedRanges,
      userAgent: req.get('User-Agent')
    });

    return res.status(403).json({
      success: false,
      error: 'Access denied from this location'
    });
  }

  next();
};

/**
 * Middleware to enforce rate limiting per user
 */
const userRateLimit = () => {
  const userRequests = new Map();
  const WINDOW_MS = 15 * 60 * 1000; // 15 minutes
  const MAX_REQUESTS = 1000; // per user per window

  return (req, res, next) => {
    if (!req.user) {
      return next();
    }

    const userId = req.user.sub;
    const now = Date.now();
    
    if (!userRequests.has(userId)) {
      userRequests.set(userId, { count: 1, resetTime: now + WINDOW_MS });
      return next();
    }

    const userLimit = userRequests.get(userId);
    
    if (now > userLimit.resetTime) {
      // Reset window
      userRequests.set(userId, { count: 1, resetTime: now + WINDOW_MS });
      return next();
    }

    if (userLimit.count >= MAX_REQUESTS) {
      logger.warn('User rate limit exceeded', {
        userId,
        count: userLimit.count,
        ip: req.ip
      });

      return res.status(429).json({
        success: false,
        error: 'Too many requests, please try again later'
      });
    }

    userLimit.count++;
    next();
  };
};

module.exports = {
  verifyToken,
  requireRole,
  validateIPAddress,
  userRateLimit
};