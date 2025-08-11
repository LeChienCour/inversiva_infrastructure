// Enhanced AWS Cognito Authentication Service for Next.js
// This service provides comprehensive authentication functionality

import { Amplify } from 'aws-amplify';
import { Auth } from '@aws-amplify/auth';

/**
 * Authentication Service Class
 * Provides methods for user authentication, session management, and user operations
 */
class AuthenticationService {
  constructor() {
    this.isConfigured = false;
    this.config = null;
  }

  /**
   * Initialize the authentication service with Cognito configuration
   * @param {Object} config - Cognito configuration object
   */
  configure(config) {
    this.config = config;
    
    Amplify.configure({
      Auth: {
        region: config.region,
        userPoolId: config.userPoolId,
        userPoolWebClientId: config.userPoolClientId,
        identityPoolId: config.identityPoolId,
        oauth: {
          domain: config.oauth?.domain,
          scope: config.oauth?.scope || ['email', 'openid', 'profile'],
          redirectSignIn: config.oauth?.redirectSignIn,
          redirectSignOut: config.oauth?.redirectSignOut,
          responseType: config.oauth?.responseType || 'code'
        }
      }
    });

    this.isConfigured = true;
  }

  /**
   * Check if the service is properly configured
   */
  _checkConfiguration() {
    if (!this.isConfigured) {
      throw new Error('AuthenticationService not configured. Call configure() first.');
    }
  }

  /**
   * Sign up a new user
   * @param {string} email - User email
   * @param {string} password - User password
   * @param {Object} attributes - Additional user attributes
   * @returns {Promise<Object>} Result object with success status
   */
  async signUp(email, password, attributes = {}) {
    this._checkConfiguration();
    
    try {
      const { user } = await Auth.signUp({
        username: email,
        password,
        attributes: {
          email,
          ...attributes
        }
      });
      
      return { 
        success: true, 
        user,
        message: 'User registered successfully. Please check your email for verification code.'
      };
    } catch (error) {
      console.error('Sign up error:', error);
      return { 
        success: false, 
        error: error.message,
        code: error.code
      };
    }
  }

  /**
   * Confirm user sign up with verification code
   * @param {string} email - User email
   * @param {string} code - Verification code
   * @returns {Promise<Object>} Result object with success status
   */
  async confirmSignUp(email, code) {
    this._checkConfiguration();
    
    try {
      await Auth.confirmSignUp(email, code);
      return { 
        success: true,
        message: 'Email verified successfully. You can now sign in.'
      };
    } catch (error) {
      console.error('Confirm sign up error:', error);
      return { 
        success: false, 
        error: error.message,
        code: error.code
      };
    }
  }

  /**
   * Resend verification code
   * @param {string} email - User email
   * @returns {Promise<Object>} Result object with success status
   */
  async resendConfirmationCode(email) {
    this._checkConfiguration();
    
    try {
      await Auth.resendSignUp(email);
      return { 
        success: true,
        message: 'Verification code sent to your email.'
      };
    } catch (error) {
      console.error('Resend confirmation code error:', error);
      return { 
        success: false, 
        error: error.message,
        code: error.code
      };
    }
  }

  /**
   * Sign in user
   * @param {string} email - User email
   * @param {string} password - User password
   * @returns {Promise<Object>} Result object with success status and user data
   */
  async signIn(email, password) {
    this._checkConfiguration();
    
    try {
      const user = await Auth.signIn(email, password);
      
      // Handle MFA challenge if required
      if (user.challengeName === 'SMS_MFA' || user.challengeName === 'SOFTWARE_TOKEN_MFA') {
        return {
          success: false,
          requiresMFA: true,
          challengeName: user.challengeName,
          user,
          message: 'MFA verification required.'
        };
      }
      
      return { 
        success: true, 
        user,
        message: 'Signed in successfully.'
      };
    } catch (error) {
      console.error('Sign in error:', error);
      return { 
        success: false, 
        error: error.message,
        code: error.code
      };
    }
  }

  /**
   * Confirm MFA challenge
   * @param {Object} user - User object from sign in
   * @param {string} code - MFA code
   * @returns {Promise<Object>} Result object with success status
   */
  async confirmMFA(user, code) {
    this._checkConfiguration();
    
    try {
      const signedUser = await Auth.confirmSignIn(user, code);
      return { 
        success: true, 
        user: signedUser,
        message: 'MFA verified successfully.'
      };
    } catch (error) {
      console.error('MFA confirmation error:', error);
      return { 
        success: false, 
        error: error.message,
        code: error.code
      };
    }
  }

  /**
   * Sign out user
   * @returns {Promise<Object>} Result object with success status
   */
  async signOut() {
    this._checkConfiguration();
    
    try {
      await Auth.signOut();
      return { 
        success: true,
        message: 'Signed out successfully.'
      };
    } catch (error) {
      console.error('Sign out error:', error);
      return { 
        success: false, 
        error: error.message,
        code: error.code
      };
    }
  }

  /**
   * Get current authenticated user
   * @returns {Promise<Object>} Result object with user data
   */
  async getCurrentUser() {
    this._checkConfiguration();
    
    try {
      const user = await Auth.currentAuthenticatedUser();
      return { 
        success: true, 
        user,
        isAuthenticated: true
      };
    } catch (error) {
      return { 
        success: false, 
        error: 'No authenticated user',
        isAuthenticated: false
      };
    }
  }

  /**
   * Get user session and tokens
   * @returns {Promise<Object>} Result object with session data
   */
  async getSession() {
    this._checkConfiguration();
    
    try {
      const session = await Auth.currentSession();
      return {
        success: true,
        session,
        accessToken: session.getAccessToken().getJwtToken(),
        idToken: session.getIdToken().getJwtToken(),
        refreshToken: session.getRefreshToken().getToken(),
        isValid: session.isValid()
      };
    } catch (error) {
      console.error('Get session error:', error);
      return { 
        success: false, 
        error: error.message,
        code: error.code
      };
    }
  }

  /**
   * Refresh user session
   * @returns {Promise<Object>} Result object with refreshed session
   */
  async refreshSession() {
    this._checkConfiguration();
    
    try {
      const session = await Auth.currentSession();
      return { 
        success: true, 
        session,
        message: 'Session refreshed successfully.'
      };
    } catch (error) {
      console.error('Refresh session error:', error);
      return { 
        success: false, 
        error: error.message,
        code: error.code
      };
    }
  }

  /**
   * Change user password
   * @param {string} oldPassword - Current password
   * @param {string} newPassword - New password
   * @returns {Promise<Object>} Result object with success status
   */
  async changePassword(oldPassword, newPassword) {
    this._checkConfiguration();
    
    try {
      const user = await Auth.currentAuthenticatedUser();
      await Auth.changePassword(user, oldPassword, newPassword);
      return { 
        success: true,
        message: 'Password changed successfully.'
      };
    } catch (error) {
      console.error('Change password error:', error);
      return { 
        success: false, 
        error: error.message,
        code: error.code
      };
    }
  }

  /**
   * Initiate forgot password flow
   * @param {string} email - User email
   * @returns {Promise<Object>} Result object with success status
   */
  async forgotPassword(email) {
    this._checkConfiguration();
    
    try {
      await Auth.forgotPassword(email);
      return { 
        success: true,
        message: 'Password reset code sent to your email.'
      };
    } catch (error) {
      console.error('Forgot password error:', error);
      return { 
        success: false, 
        error: error.message,
        code: error.code
      };
    }
  }

  /**
   * Confirm forgot password with code and new password
   * @param {string} email - User email
   * @param {string} code - Reset code
   * @param {string} newPassword - New password
   * @returns {Promise<Object>} Result object with success status
   */
  async forgotPasswordSubmit(email, code, newPassword) {
    this._checkConfiguration();
    
    try {
      await Auth.forgotPasswordSubmit(email, code, newPassword);
      return { 
        success: true,
        message: 'Password reset successfully. You can now sign in with your new password.'
      };
    } catch (error) {
      console.error('Forgot password submit error:', error);
      return { 
        success: false, 
        error: error.message,
        code: error.code
      };
    }
  }

  /**
   * Update user attributes
   * @param {Object} attributes - Attributes to update
   * @returns {Promise<Object>} Result object with success status
   */
  async updateUserAttributes(attributes) {
    this._checkConfiguration();
    
    try {
      const user = await Auth.currentAuthenticatedUser();
      await Auth.updateUserAttributes(user, attributes);
      return { 
        success: true,
        message: 'User attributes updated successfully.'
      };
    } catch (error) {
      console.error('Update user attributes error:', error);
      return { 
        success: false, 
        error: error.message,
        code: error.code
      };
    }
  }

  /**
   * Delete user account
   * @returns {Promise<Object>} Result object with success status
   */
  async deleteUser() {
    this._checkConfiguration();
    
    try {
      const user = await Auth.currentAuthenticatedUser();
      await Auth.deleteUser();
      return { 
        success: true,
        message: 'User account deleted successfully.'
      };
    } catch (error) {
      console.error('Delete user error:', error);
      return { 
        success: false, 
        error: error.message,
        code: error.code
      };
    }
  }

  /**
   * Check if user is authenticated
   * @returns {Promise<boolean>} Authentication status
   */
  async isAuthenticated() {
    const result = await this.getCurrentUser();
    return result.isAuthenticated;
  }

  /**
   * Get user groups/roles
   * @returns {Promise<Array>} Array of user groups
   */
  async getUserGroups() {
    this._checkConfiguration();
    
    try {
      const session = await Auth.currentSession();
      const payload = session.getAccessToken().payload;
      return payload['cognito:groups'] || [];
    } catch (error) {
      console.error('Get user groups error:', error);
      return [];
    }
  }
}

// Create and export a singleton instance
const authService = new AuthenticationService();

export default authService;

// Export the class for custom instances if needed
export { AuthenticationService };

// Helper function to get configuration from environment variables
export const getAuthConfigFromEnv = () => ({
  region: process.env.NEXT_PUBLIC_AWS_REGION,
  userPoolId: process.env.NEXT_PUBLIC_COGNITO_USER_POOL_ID,
  userPoolClientId: process.env.NEXT_PUBLIC_COGNITO_USER_POOL_CLIENT_ID,
  identityPoolId: process.env.NEXT_PUBLIC_COGNITO_IDENTITY_POOL_ID,
  oauth: {
    domain: process.env.NEXT_PUBLIC_COGNITO_DOMAIN,
    scope: ['email', 'openid', 'profile'],
    redirectSignIn: process.env.NEXT_PUBLIC_OAUTH_REDIRECT_URI,
    redirectSignOut: process.env.NEXT_PUBLIC_OAUTH_LOGOUT_URI,
    responseType: 'code'
  }
});