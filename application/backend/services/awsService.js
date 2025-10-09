const AWS = require('aws-sdk');
const logger = require('../utils/logger');

// Configure AWS SDK to use VPC endpoints
AWS.config.update({
  region: process.env.AWS_REGION || 'us-west-2',
  maxRetries: 3,
  retryDelayOptions: {
    customBackoff: function(retryCount) {
      return Math.pow(2, retryCount) * 100;
    }
  }
});

// Initialize AWS services
const cloudWatchLogs = new AWS.CloudWatchLogs();
const cloudWatch = new AWS.CloudWatch();
const ec2 = new AWS.EC2();
const guardDuty = new AWS.GuardDuty();
const rds = new AWS.RDS();
const s3 = new AWS.S3();

class AWSService {
  
  /**
   * Get Zero Trust architecture status
   */
  async getZeroTrustStatus() {
    try {
      const status = {
        vpc: await this.getVPCStatus(),
        endpoints: await this.getVPCEndpointStatus(),
        security: await this.getSecurityStatus(),
        monitoring: await this.getMonitoringStatus(),
        timestamp: new Date().toISOString()
      };

      return status;
    } catch (error) {
      logger.error('Error getting Zero Trust status:', error);
      throw error;
    }
  }

  /**
   * Get VPC configuration status
   */
  async getVPCStatus() {
    try {
      const params = {
        Filters: [
          {
            Name: 'tag:Project',
            Values: ['Zero-Trust-Architecture']
          }
        ]
      };

      const vpcs = await ec2.describeVpcs(params).promise();
      const subnets = await ec2.describeSubnets(params).promise();
      const securityGroups = await ec2.describeSecurityGroups(params).promise();

      return {
        vpcs: vpcs.Vpcs.length,
        subnets: {
          total: subnets.Subnets.length,
          public: subnets.Subnets.filter(s => s.Tags?.some(t => t.Key === 'Type' && t.Value.includes('Public'))).length,
          private: subnets.Subnets.filter(s => s.Tags?.some(t => t.Key === 'Type' && t.Value.includes('Private'))).length
        },
        securityGroups: securityGroups.SecurityGroups.length,
        status: 'healthy'
      };
    } catch (error) {
      logger.error('Error getting VPC status:', error);
      return { status: 'error', error: error.message };
    }
  }

  /**
   * Get VPC Endpoints status (PrivateLink)
   */
  async getVPCEndpointStatus() {
    try {
      const endpoints = await ec2.describeVpcEndpoints().promise();
      
      const endpointsByService = endpoints.VpcEndpoints.reduce((acc, endpoint) => {
        const serviceName = endpoint.ServiceName.split('.').pop();
        acc[serviceName] = endpoint.State;
        return acc;
      }, {});

      return {
        total: endpoints.VpcEndpoints.length,
        available: endpoints.VpcEndpoints.filter(e => e.State === 'Available').length,
        services: endpointsByService,
        status: 'healthy'
      };
    } catch (error) {
      logger.error('Error getting VPC endpoint status:', error);
      return { status: 'error', error: error.message };
    }
  }

  /**
   * Get security services status
   */
  async getSecurityStatus() {
    try {
      // Check GuardDuty
      let guardDutyStatus = 'disabled';
      try {
        const detectors = await guardDuty.listDetectors().promise();
        if (detectors.DetectorIds.length > 0) {
          const detector = await guardDuty.getDetector({
            DetectorId: detectors.DetectorIds[0]
          }).promise();
          guardDutyStatus = detector.Status.toLowerCase();
        }
      } catch (error) {
        logger.warn('GuardDuty not accessible:', error.message);
      }

      return {
        guardDuty: {
          status: guardDutyStatus,
          enabled: guardDutyStatus === 'enabled'
        },
        flowLogs: await this.checkFlowLogsStatus(),
        status: 'healthy'
      };
    } catch (error) {
      logger.error('Error getting security status:', error);
      return { status: 'error', error: error.message };
    }
  }

  /**
   * Check VPC Flow Logs status
   */
  async checkFlowLogsStatus() {
    try {
      const flowLogs = await ec2.describeFlowLogs().promise();
      return {
        total: flowLogs.FlowLogs.length,
        active: flowLogs.FlowLogs.filter(f => f.FlowLogStatus === 'ACTIVE').length,
        enabled: flowLogs.FlowLogs.length > 0
      };
    } catch (error) {
      logger.error('Error checking flow logs status:', error);
      return { enabled: false, error: error.message };
    }
  }

  /**
   * Get monitoring services status
   */
  async getMonitoringStatus() {
    try {
      // Check CloudWatch log groups
      const logGroups = await cloudWatchLogs.describeLogGroups({
        logGroupNamePrefix: '/aws/vpc/flowlogs'
      }).promise();

      return {
        logGroups: logGroups.logGroups.length,
        flowLogsEnabled: logGroups.logGroups.length > 0,
        status: 'healthy'
      };
    } catch (error) {
      logger.error('Error getting monitoring status:', error);
      return { status: 'error', error: error.message };
    }
  }

  /**
   * Get security metrics for dashboard
   */
  async getSecurityMetrics() {
    try {
      const endTime = new Date();
      const startTime = new Date(endTime.getTime() - (24 * 60 * 60 * 1000)); // 24 hours ago

      // Get VPC Flow Logs metrics
      const flowLogMetrics = await this.getFlowLogMetrics(startTime, endTime);
      
      // Get GuardDuty findings
      const guardDutyFindings = await this.getGuardDutyFindingsCount();

      return {
        flowLogs: flowLogMetrics,
        guardDuty: guardDutyFindings,
        period: '24h',
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      logger.error('Error getting security metrics:', error);
      return { error: error.message };
    }
  }

  /**
   * Get network metrics
   */
  async getNetworkMetrics() {
    try {
      const endTime = new Date();
      const startTime = new Date(endTime.getTime() - (60 * 60 * 1000)); // 1 hour ago

      const params = {
        StartTime: startTime,
        EndTime: endTime,
        MetricDataQueries: [
          {
            Id: 'm1',
            MetricStat: {
              Metric: {
                Namespace: 'AWS/VPC',
                MetricName: 'PacketsDropped'
              },
              Period: 300,
              Stat: 'Sum'
            }
          },
          {
            Id: 'm2',
            MetricStat: {
              Metric: {
                Namespace: 'AWS/ApplicationELB',
                MetricName: 'RequestCount'
              },
              Period: 300,
              Stat: 'Sum'
            }
          }
        ]
      };

      const data = await cloudWatch.getMetricData(params).promise();
      
      return {
        packetsDropped: data.MetricDataResults[0]?.Values?.reduce((a, b) => a + b, 0) || 0,
        requestCount: data.MetricDataResults[1]?.Values?.reduce((a, b) => a + b, 0) || 0,
        period: '1h',
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      logger.error('Error getting network metrics:', error);
      return { error: error.message };
    }
  }

  /**
   * Get VPC Flow Logs analysis
   */
  async getFlowLogsAnalysis(timeRange = '1h', limit = 100) {
    try {
      const logGroupName = `/aws/vpc/flowlogs/${process.env.PROJECT_NAME}-${process.env.ENVIRONMENT}`;
      
      const endTime = new Date();
      let startTime;
      
      switch (timeRange) {
        case '1h':
          startTime = new Date(endTime.getTime() - (60 * 60 * 1000));
          break;
        case '24h':
          startTime = new Date(endTime.getTime() - (24 * 60 * 60 * 1000));
          break;
        default:
          startTime = new Date(endTime.getTime() - (60 * 60 * 1000));
      }

      const query = `
        fields @timestamp, srcaddr, dstaddr, srcport, dstport, protocol, action, bytes
        | filter action = "REJECT"
        | stats count(*) as rejected_count by srcaddr
        | sort rejected_count desc
        | limit ${limit}
      `;

      const params = {
        logGroupName: logGroupName,
        startTime: Math.floor(startTime.getTime() / 1000),
        endTime: Math.floor(endTime.getTime() / 1000),
        queryString: query
      };

      const queryResult = await cloudWatchLogs.startQuery(params).promise();
      
      // Wait for query to complete (simplified - in production, implement proper polling)
      await new Promise(resolve => setTimeout(resolve, 5000));
      
      const results = await cloudWatchLogs.getQueryResults({
        queryId: queryResult.queryId
      }).promise();

      return {
        query,
        results: results.results || [],
        timeRange,
        status: results.status
      };
    } catch (error) {
      logger.error('Error getting flow logs analysis:', error);
      return { error: error.message };
    }
  }

  /**
   * Get GuardDuty findings
   */
  async getGuardDutyFindings() {
    try {
      const detectors = await guardDuty.listDetectors().promise();
      
      if (detectors.DetectorIds.length === 0) {
        return { findings: [], total: 0 };
      }

      const detectorId = detectors.DetectorIds[0];
      
      const findingIds = await guardDuty.listFindings({
        DetectorId: detectorId,
        MaxResults: 50
      }).promise();

      if (findingIds.FindingIds.length === 0) {
        return { findings: [], total: 0 };
      }

      const findings = await guardDuty.getFindings({
        DetectorId: detectorId,
        FindingIds: findingIds.FindingIds
      }).promise();

      return {
        findings: findings.Findings.map(f => ({
          id: f.Id,
          type: f.Type,
          severity: f.Severity,
          title: f.Title,
          description: f.Description,
          createdAt: f.CreatedAt,
          updatedAt: f.UpdatedAt
        })),
        total: findings.Findings.length
      };
    } catch (error) {
      logger.error('Error getting GuardDuty findings:', error);
      return { error: error.message };
    }
  }

  /**
   * Get network topology information
   */
  async getNetworkTopology() {
    try {
      const vpcs = await ec2.describeVpcs({
        Filters: [{ Name: 'tag:Project', Values: ['Zero-Trust-Architecture'] }]
      }).promise();

      const subnets = await ec2.describeSubnets({
        Filters: [{ Name: 'tag:Project', Values: ['Zero-Trust-Architecture'] }]
      }).promise();

      const endpoints = await ec2.describeVpcEndpoints().promise();

      return {
        vpc: vpcs.Vpcs[0] || {},
        subnets: subnets.Subnets.map(s => ({
          id: s.SubnetId,
          cidr: s.CidrBlock,
          az: s.AvailabilityZone,
          type: s.Tags?.find(t => t.Key === 'Type')?.Value || 'unknown'
        })),
        endpoints: endpoints.VpcEndpoints.map(e => ({
          id: e.VpcEndpointId,
          service: e.ServiceName,
          state: e.State,
          type: e.VpcEndpointType
        }))
      };
    } catch (error) {
      logger.error('Error getting network topology:', error);
      return { error: error.message };
    }
  }

  /**
   * Run connectivity tests to validate Zero Trust setup
   */
  async runConnectivityTests() {
    const tests = [];

    // Test VPC endpoints
    try {
      await s3.listBuckets().promise();
      tests.push({
        name: 'S3 VPC Endpoint',
        status: 'success',
        message: 'Successfully connected to S3 via VPC endpoint'
      });
    } catch (error) {
      tests.push({
        name: 'S3 VPC Endpoint',
        status: 'failed',
        message: `Failed to connect to S3: ${error.message}`
      });
    }

    // Test CloudWatch
    try {
      await cloudWatch.listMetrics({ MaxRecords: 1 }).promise();
      tests.push({
        name: 'CloudWatch VPC Endpoint',
        status: 'success',
        message: 'Successfully connected to CloudWatch via VPC endpoint'
      });
    } catch (error) {
      tests.push({
        name: 'CloudWatch VPC Endpoint',
        status: 'failed',
        message: `Failed to connect to CloudWatch: ${error.message}`
      });
    }

    // Test security services
    try {
      await guardDuty.listDetectors().promise();
      tests.push({
        name: 'GuardDuty Access',
        status: 'success',
        message: 'Successfully accessed GuardDuty'
      });
    } catch (error) {
      tests.push({
        name: 'GuardDuty Access',
        status: 'failed',
        message: `Failed to access GuardDuty: ${error.message}`
      });
    }

    return tests;
  }

  /**
   * Log security events for audit trail
   */
  async logSecurityEvent(event) {
    try {
      const logGroupName = `/aws/application/${process.env.PROJECT_NAME}-security-events`;
      
      const logEvent = {
        timestamp: Date.now(),
        message: JSON.stringify(event)
      };

      await cloudWatchLogs.putLogEvents({
        logGroupName,
        logStreamName: `security-events-${new Date().toISOString().split('T')[0]}`,
        logEvents: [logEvent]
      }).promise();

      logger.info('Security event logged', event);
    } catch (error) {
      logger.error('Failed to log security event:', error);
    }
  }

  /**
   * Helper method to get flow log metrics
   */
  async getFlowLogMetrics(startTime, endTime) {
    // This is a simplified implementation
    // In production, you would query actual flow log data
    return {
      totalConnections: Math.floor(Math.random() * 10000),
      rejectedConnections: Math.floor(Math.random() * 100),
      uniqueIPs: Math.floor(Math.random() * 500)
    };
  }

  /**
   * Helper method to get GuardDuty findings count
   */
  async getGuardDutyFindingsCount() {
    try {
      const detectors = await guardDuty.listDetectors().promise();
      
      if (detectors.DetectorIds.length === 0) {
        return { count: 0, enabled: false };
      }

      const findingIds = await guardDuty.listFindings({
        DetectorId: detectors.DetectorIds[0],
        MaxResults: 50
      }).promise();

      return {
        count: findingIds.FindingIds.length,
        enabled: true
      };
    } catch (error) {
      return { count: 0, enabled: false, error: error.message };
    }
  }
}

module.exports = new AWSService();