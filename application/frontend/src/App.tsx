import React, { useEffect, useState } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { Amplify } from 'aws-amplify';
import Login from './components/Login';
import Dashboard from './components/Dashboard';
import NetworkTopology from './components/NetworkTopology';
import SecurityMetrics from './components/SecurityMetrics';
import FlowLogs from './components/FlowLogs';
import Layout from './components/Layout';
import { AuthProvider, useAuth } from './context/AuthContext';
import { Shield, AlertTriangle, CheckCircle, XCircle } from 'lucide-react';

// Configure Amplify with Cognito settings
Amplify.configure({
  Auth: {
    region: import.meta.env.VITE_AWS_REGION || 'us-west-2',
    userPoolId: import.meta.env.VITE_COGNITO_USER_POOL_ID,
    userPoolWebClientId: import.meta.env.VITE_COGNITO_CLIENT_ID,
  }
});

// Protected Route Component
const ProtectedRoute: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Verifying authentication...</p>
        </div>
      </div>
    );
  }

  return user ? <>{children}</> : <Navigate to="/login" />;
};

// Zero Trust Status Component
const ZeroTrustStatus: React.FC = () => {
  const [status, setStatus] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchStatus = async () => {
      try {
        const response = await fetch(`${import.meta.env.VITE_API_URL}/api/zero-trust-status`);
        const data = await response.json();
        setStatus(data.data);
      } catch (error) {
        console.error('Failed to fetch Zero Trust status:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchStatus();
  }, []);

  if (loading) {
    return (
      <div className="bg-white p-4 rounded-lg shadow border-l-4 border-blue-500">
        <div className="flex items-center">
          <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-blue-600"></div>
          <span className="ml-2 text-sm text-gray-600">Checking Zero Trust status...</span>
        </div>
      </div>
    );
  }

  const getStatusIcon = (statusValue: string) => {
    switch (statusValue) {
      case 'healthy':
        return <CheckCircle className="h-5 w-5 text-green-500" />;
      case 'warning':
        return <AlertTriangle className="h-5 w-5 text-yellow-500" />;
      case 'error':
        return <XCircle className="h-5 w-5 text-red-500" />;
      default:
        return <Shield className="h-5 w-5 text-gray-500" />;
    }
  };

  const getStatusColor = (statusValue: string) => {
    switch (statusValue) {
      case 'healthy':
        return 'border-green-500 bg-green-50';
      case 'warning':
        return 'border-yellow-500 bg-yellow-50';
      case 'error':
        return 'border-red-500 bg-red-50';
      default:
        return 'border-gray-500 bg-gray-50';
    }
  };

  return (
    <div className="mb-6">
      <h2 className="text-lg font-semibold text-gray-900 mb-4 flex items-center">
        <Shield className="h-5 w-5 mr-2" />
        Zero Trust Architecture Status
      </h2>
      
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* VPC Status */}
        <div className={`p-4 rounded-lg shadow border-l-4 ${getStatusColor(status?.vpc?.status || 'unknown')}`}>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-900">VPC</p>
              <p className="text-xs text-gray-600">Network Segmentation</p>
            </div>
            {getStatusIcon(status?.vpc?.status)}
          </div>
          <div className="mt-2 text-xs text-gray-500">
            {status?.vpc?.subnets?.total || 0} subnets, {status?.vpc?.securityGroups || 0} security groups
          </div>
        </div>

        {/* Endpoints Status */}
        <div className={`p-4 rounded-lg shadow border-l-4 ${getStatusColor(status?.endpoints?.status || 'unknown')}`}>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-900">PrivateLink</p>
              <p className="text-xs text-gray-600">VPC Endpoints</p>
            </div>
            {getStatusIcon(status?.endpoints?.status)}
          </div>
          <div className="mt-2 text-xs text-gray-500">
            {status?.endpoints?.available || 0}/{status?.endpoints?.total || 0} available
          </div>
        </div>

        {/* Security Status */}
        <div className={`p-4 rounded-lg shadow border-l-4 ${getStatusColor(status?.security?.status || 'unknown')}`}>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-900">Security</p>
              <p className="text-xs text-gray-600">GuardDuty & Flow Logs</p>
            </div>
            {getStatusIcon(status?.security?.status)}
          </div>
          <div className="mt-2 text-xs text-gray-500">
            GuardDuty: {status?.security?.guardDuty?.enabled ? 'Enabled' : 'Disabled'}
          </div>
        </div>

        {/* Monitoring Status */}
        <div className={`p-4 rounded-lg shadow border-l-4 ${getStatusColor(status?.monitoring?.status || 'unknown')}`}>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-900">Monitoring</p>
              <p className="text-xs text-gray-600">CloudWatch Logs</p>
            </div>
            {getStatusIcon(status?.monitoring?.status)}
          </div>
          <div className="mt-2 text-xs text-gray-500">
            {status?.monitoring?.logGroups || 0} log groups
          </div>
        </div>
      </div>
    </div>
  );
};

// Main App Component
const AppContent: React.FC = () => {
  const { user } = useAuth();

  return (
    <Router>
      <Routes>
        <Route path="/login" element={user ? <Navigate to="/" /> : <Login />} />
        <Route
          path="/*"
          element={
            <ProtectedRoute>
              <Layout>
                <Routes>
                  <Route path="/" element={
                    <>
                      <ZeroTrustStatus />
                      <Dashboard />
                    </>
                  } />
                  <Route path="/network" element={<NetworkTopology />} />
                  <Route path="/security" element={<SecurityMetrics />} />
                  <Route path="/logs" element={<FlowLogs />} />
                </Routes>
              </Layout>
            </ProtectedRoute>
          }
        />
      </Routes>
    </Router>
  );
};

// Root App Component
const App: React.FC = () => {
  return (
    <div className="min-h-screen bg-gray-50">
      <AuthProvider>
        <AppContent />
      </AuthProvider>
    </div>
  );
};

export default App;