// Next.js integration example for AWS Cognito
// This file demonstrates how to use the Cognito module outputs in a Next.js application

import { Amplify } from 'aws-amplify';
import { Auth } from '@aws-amplify/auth';

// Configuration object from Terraform output
const cognitoConfig = {
  userPoolId: process.env.NEXT_PUBLIC_COGNITO_USER_POOL_ID,
  userPoolClientId: process.env.NEXT_PUBLIC_COGNITO_USER_POOL_CLIENT_ID,
  identityPoolId: process.env.NEXT_PUBLIC_COGNITO_IDENTITY_POOL_ID,
  region: process.env.NEXT_PUBLIC_AWS_REGION,
  oauth: {
    domain: process.env.NEXT_PUBLIC_COGNITO_DOMAIN,
    scope: ['email', 'openid', 'profile'],
    redirectUri: process.env.NEXT_PUBLIC_OAUTH_REDIRECT_URI,
    responseType: 'code'
  }
};

// Configure Amplify with Cognito settings
Amplify.configure({
  Auth: {
    region: cognitoConfig.region,
    userPoolId: cognitoConfig.userPoolId,
    userPoolWebClientId: cognitoConfig.userPoolClientId,
    identityPoolId: cognitoConfig.identityPoolId,
    oauth: {
      domain: cognitoConfig.oauth.domain,
      scope: cognitoConfig.oauth.scope,
      redirectSignIn: cognitoConfig.oauth.redirectUri,
      redirectSignOut: process.env.NEXT_PUBLIC_OAUTH_LOGOUT_URI,
      responseType: cognitoConfig.oauth.responseType
    }
  }
});

// Authentication helper functions
export const authService = {
  // Sign up a new user
  async signUp(email, password, attributes = {}) {
    try {
      const { user } = await Auth.signUp({
        username: email,
        password,
        attributes: {
          email,
          ...attributes
        }
      });
      return { success: true, user };
    } catch (error) {
      console.error('Sign up error:', error);
      return { success: false, error: error.message };
    }
  },

  // Confirm sign up with verification code
  async confirmSignUp(email, code) {
    try {
      await Auth.confirmSignUp(email, code);
      return { success: true };
    } catch (error) {
      console.error('Confirm sign up error:', error);
      return { success: false, error: error.message };
    }
  },

  // Sign in user
  async signIn(email, password) {
    try {
      const user = await Auth.signIn(email, password);
      return { success: true, user };
    } catch (error) {
      console.error('Sign in error:', error);
      return { success: false, error: error.message };
    }
  },

  // Sign out user
  async signOut() {
    try {
      await Auth.signOut();
      return { success: true };
    } catch (error) {
      console.error('Sign out error:', error);
      return { success: false, error: error.message };
    }
  },

  // Get current authenticated user
  async getCurrentUser() {
    try {
      const user = await Auth.currentAuthenticatedUser();
      return { success: true, user };
    } catch (error) {
      return { success: false, error: 'No authenticated user' };
    }
  },

  // Get user session and tokens
  async getSession() {
    try {
      const session = await Auth.currentSession();
      return {
        success: true,
        session,
        accessToken: session.getAccessToken().getJwtToken(),
        idToken: session.getIdToken().getJwtToken(),
        refreshToken: session.getRefreshToken().getToken()
      };
    } catch (error) {
      console.error('Get session error:', error);
      return { success: false, error: error.message };
    }
  },

  // Refresh user session
  async refreshSession() {
    try {
      const session = await Auth.currentSession();
      return { success: true, session };
    } catch (error) {
      console.error('Refresh session error:', error);
      return { success: false, error: error.message };
    }
  },

  // Change password
  async changePassword(oldPassword, newPassword) {
    try {
      const user = await Auth.currentAuthenticatedUser();
      await Auth.changePassword(user, oldPassword, newPassword);
      return { success: true };
    } catch (error) {
      console.error('Change password error:', error);
      return { success: false, error: error.message };
    }
  },

  // Forgot password
  async forgotPassword(email) {
    try {
      await Auth.forgotPassword(email);
      return { success: true };
    } catch (error) {
      console.error('Forgot password error:', error);
      return { success: false, error: error.message };
    }
  },

  // Confirm forgot password with code
  async forgotPasswordSubmit(email, code, newPassword) {
    try {
      await Auth.forgotPasswordSubmit(email, code, newPassword);
      return { success: true };
    } catch (error) {
      console.error('Forgot password submit error:', error);
      return { success: false, error: error.message };
    }
  }
};

// React hook for authentication state
import { useState, useEffect, createContext, useContext } from 'react';

const AuthContext = createContext();

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    checkAuthState();
  }, []);

  const checkAuthState = async () => {
    try {
      const currentUser = await Auth.currentAuthenticatedUser();
      setUser(currentUser);
    } catch (error) {
      setUser(null);
    } finally {
      setLoading(false);
    }
  };

  const signIn = async (email, password) => {
    const result = await authService.signIn(email, password);
    if (result.success) {
      setUser(result.user);
    }
    return result;
  };

  const signOut = async () => {
    const result = await authService.signOut();
    if (result.success) {
      setUser(null);
    }
    return result;
  };

  const value = {
    user,
    loading,
    signIn,
    signOut,
    signUp: authService.signUp,
    confirmSignUp: authService.confirmSignUp,
    changePassword: authService.changePassword,
    forgotPassword: authService.forgotPassword,
    forgotPasswordSubmit: authService.forgotPasswordSubmit,
    getSession: authService.getSession,
    refreshSession: authService.refreshSession
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

// Example usage in a Next.js page
export const ExampleLoginPage = () => {
  const { signIn, user, loading } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    
    const result = await signIn(email, password);
    if (!result.success) {
      setError(result.error);
    }
  };

  if (loading) return <div>Loading...</div>;
  if (user) return <div>Welcome, {user.attributes.email}!</div>;

  return (
    <form onSubmit={handleSubmit}>
      <div>
        <label>Email:</label>
        <input
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
        />
      </div>
      <div>
        <label>Password:</label>
        <input
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
        />
      </div>
      {error && <div style={{ color: 'red' }}>{error}</div>}
      <button type="submit">Sign In</button>
    </form>
  );
};

// Environment variables needed in .env.local:
/*
NEXT_PUBLIC_COGNITO_USER_POOL_ID=us-east-1_XXXXXXXXX
NEXT_PUBLIC_COGNITO_USER_POOL_CLIENT_ID=XXXXXXXXXXXXXXXXXXXXXXXXXX
NEXT_PUBLIC_COGNITO_IDENTITY_POOL_ID=us-east-1:XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
NEXT_PUBLIC_AWS_REGION=us-east-1
NEXT_PUBLIC_COGNITO_DOMAIN=my-app-dev.auth.us-east-1.amazoncognito.com
NEXT_PUBLIC_OAUTH_REDIRECT_URI=http://localhost:3000/auth/callback
NEXT_PUBLIC_OAUTH_LOGOUT_URI=http://localhost:3000/auth/logout
*/