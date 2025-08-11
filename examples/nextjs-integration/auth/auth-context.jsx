// React Context for Authentication State Management
// Provides authentication state and methods throughout the Next.js application

import React, { createContext, useContext, useReducer, useEffect } from 'react';
import authService, { getAuthConfigFromEnv } from './auth-service';

// Authentication action types
const AUTH_ACTIONS = {
  SET_LOADING: 'SET_LOADING',
  SET_USER: 'SET_USER',
  SET_ERROR: 'SET_ERROR',
  CLEAR_ERROR: 'CLEAR_ERROR',
  SET_MFA_CHALLENGE: 'SET_MFA_CHALLENGE',
  CLEAR_MFA_CHALLENGE: 'CLEAR_MFA_CHALLENGE',
  LOGOUT: 'LOGOUT'
};

// Initial authentication state
const initialState = {
  user: null,
  isAuthenticated: false,
  isLoading: true,
  error: null,
  mfaChallenge: null,
  userGroups: []
};

// Authentication reducer
const authReducer = (state, action) => {
  switch (action.type) {
    case AUTH_ACTIONS.SET_LOADING:
      return {
        ...state,
        isLoading: action.payload
      };
    
    case AUTH_ACTIONS.SET_USER:
      return {
        ...state,
        user: action.payload.user,
        isAuthenticated: !!action.payload.user,
        userGroups: action.payload.groups || [],
        isLoading: false,
        error: null
      };
    
    case AUTH_ACTIONS.SET_ERROR:
      return {
        ...state,
        error: action.payload,
        isLoading: false
      };
    
    case AUTH_ACTIONS.CLEAR_ERROR:
      return {
        ...state,
        error: null
      };
    
    case AUTH_ACTIONS.SET_MFA_CHALLENGE:
      return {
        ...state,
        mfaChallenge: action.payload,
        isLoading: false
      };
    
    case AUTH_ACTIONS.CLEAR_MFA_CHALLENGE:
      return {
        ...state,
        mfaChallenge: null
      };
    
    case AUTH_ACTIONS.LOGOUT:
      return {
        ...initialState,
        isLoading: false
      };
    
    default:
      return state;
  }
};

// Create authentication context
const AuthContext = createContext();

/**
 * Authentication Provider Component
 * Wraps the application and provides authentication state and methods
 */
export const AuthProvider = ({ children, config = null }) => {
  const [state, dispatch] = useReducer(authReducer, initialState);

  // Initialize authentication service
  useEffect(() => {
    const initializeAuth = async () => {
      try {
        // Configure auth service with provided config or environment variables
        const authConfig = config || getAuthConfigFromEnv();
        authService.configure(authConfig);
        
        // Check for existing authenticated user
        await checkAuthState();
      } catch (error) {
        console.error('Failed to initialize authentication:', error);
        dispatch({ type: AUTH_ACTIONS.SET_ERROR, payload: error.message });
      }
    };

    initializeAuth();
  }, [config]);

  /**
   * Check current authentication state
   */
  const checkAuthState = async () => {
    dispatch({ type: AUTH_ACTIONS.SET_LOADING, payload: true });
    
    try {
      const userResult = await authService.getCurrentUser();
      
      if (userResult.success) {
        const groups = await authService.getUserGroups();
        dispatch({ 
          type: AUTH_ACTIONS.SET_USER, 
          payload: { 
            user: userResult.user, 
            groups 
          } 
        });
      } else {
        dispatch({ type: AUTH_ACTIONS.SET_USER, payload: { user: null } });
      }
    } catch (error) {
      console.error('Error checking auth state:', error);
      dispatch({ type: AUTH_ACTIONS.SET_ERROR, payload: error.message });
    }
  };

  /**
   * Sign up a new user
   */
  const signUp = async (email, password, attributes = {}) => {
    dispatch({ type: AUTH_ACTIONS.SET_LOADING, payload: true });
    dispatch({ type: AUTH_ACTIONS.CLEAR_ERROR });
    
    const result = await authService.signUp(email, password, attributes);
    
    if (!result.success) {
      dispatch({ type: AUTH_ACTIONS.SET_ERROR, payload: result.error });
    }
    
    dispatch({ type: AUTH_ACTIONS.SET_LOADING, payload: false });
    return result;
  };

  /**
   * Confirm user sign up
   */
  const confirmSignUp = async (email, code) => {
    dispatch({ type: AUTH_ACTIONS.SET_LOADING, payload: true });
    dispatch({ type: AUTH_ACTIONS.CLEAR_ERROR });
    
    const result = await authService.confirmSignUp(email, code);
    
    if (!result.success) {
      dispatch({ type: AUTH_ACTIONS.SET_ERROR, payload: result.error });
    }
    
    dispatch({ type: AUTH_ACTIONS.SET_LOADING, payload: false });
    return result;
  };

  /**
   * Resend confirmation code
   */
  const resendConfirmationCode = async (email) => {
    dispatch({ type: AUTH_ACTIONS.CLEAR_ERROR });
    
    const result = await authService.resendConfirmationCode(email);
    
    if (!result.success) {
      dispatch({ type: AUTH_ACTIONS.SET_ERROR, payload: result.error });
    }
    
    return result;
  };

  /**
   * Sign in user
   */
  const signIn = async (email, password) => {
    dispatch({ type: AUTH_ACTIONS.SET_LOADING, payload: true });
    dispatch({ type: AUTH_ACTIONS.CLEAR_ERROR });
    
    const result = await authService.signIn(email, password);
    
    if (result.success) {
      const groups = await authService.getUserGroups();
      dispatch({ 
        type: AUTH_ACTIONS.SET_USER, 
        payload: { 
          user: result.user, 
          groups 
        } 
      });
    } else if (result.requiresMFA) {
      dispatch({ 
        type: AUTH_ACTIONS.SET_MFA_CHALLENGE, 
        payload: {
          user: result.user,
          challengeName: result.challengeName
        }
      });
    } else {
      dispatch({ type: AUTH_ACTIONS.SET_ERROR, payload: result.error });
    }
    
    return result;
  };

  /**
   * Confirm MFA challenge
   */
  const confirmMFA = async (code) => {
    if (!state.mfaChallenge) {
      return { success: false, error: 'No MFA challenge in progress' };
    }
    
    dispatch({ type: AUTH_ACTIONS.SET_LOADING, payload: true });
    dispatch({ type: AUTH_ACTIONS.CLEAR_ERROR });
    
    const result = await authService.confirmMFA(state.mfaChallenge.user, code);
    
    if (result.success) {
      const groups = await authService.getUserGroups();
      dispatch({ 
        type: AUTH_ACTIONS.SET_USER, 
        payload: { 
          user: result.user, 
          groups 
        } 
      });
      dispatch({ type: AUTH_ACTIONS.CLEAR_MFA_CHALLENGE });
    } else {
      dispatch({ type: AUTH_ACTIONS.SET_ERROR, payload: result.error });
    }
    
    return result;
  };

  /**
   * Sign out user
   */
  const signOut = async () => {
    dispatch({ type: AUTH_ACTIONS.SET_LOADING, payload: true });
    
    const result = await authService.signOut();
    
    if (result.success) {
      dispatch({ type: AUTH_ACTIONS.LOGOUT });
    } else {
      dispatch({ type: AUTH_ACTIONS.SET_ERROR, payload: result.error });
      dispatch({ type: AUTH_ACTIONS.SET_LOADING, payload: false });
    }
    
    return result;
  };

  /**
   * Change password
   */
  const changePassword = async (oldPassword, newPassword) => {
    dispatch({ type: AUTH_ACTIONS.CLEAR_ERROR });
    
    const result = await authService.changePassword(oldPassword, newPassword);
    
    if (!result.success) {
      dispatch({ type: AUTH_ACTIONS.SET_ERROR, payload: result.error });
    }
    
    return result;
  };

  /**
   * Forgot password
   */
  const forgotPassword = async (email) => {
    dispatch({ type: AUTH_ACTIONS.CLEAR_ERROR });
    
    const result = await authService.forgotPassword(email);
    
    if (!result.success) {
      dispatch({ type: AUTH_ACTIONS.SET_ERROR, payload: result.error });
    }
    
    return result;
  };

  /**
   * Confirm forgot password
   */
  const forgotPasswordSubmit = async (email, code, newPassword) => {
    dispatch({ type: AUTH_ACTIONS.CLEAR_ERROR });
    
    const result = await authService.forgotPasswordSubmit(email, code, newPassword);
    
    if (!result.success) {
      dispatch({ type: AUTH_ACTIONS.SET_ERROR, payload: result.error });
    }
    
    return result;
  };

  /**
   * Update user attributes
   */
  const updateUserAttributes = async (attributes) => {
    dispatch({ type: AUTH_ACTIONS.CLEAR_ERROR });
    
    const result = await authService.updateUserAttributes(attributes);
    
    if (result.success) {
      // Refresh user data
      await checkAuthState();
    } else {
      dispatch({ type: AUTH_ACTIONS.SET_ERROR, payload: result.error });
    }
    
    return result;
  };

  /**
   * Delete user account
   */
  const deleteUser = async () => {
    dispatch({ type: AUTH_ACTIONS.CLEAR_ERROR });
    
    const result = await authService.deleteUser();
    
    if (result.success) {
      dispatch({ type: AUTH_ACTIONS.LOGOUT });
    } else {
      dispatch({ type: AUTH_ACTIONS.SET_ERROR, payload: result.error });
    }
    
    return result;
  };

  /**
   * Get current session
   */
  const getSession = async () => {
    return await authService.getSession();
  };

  /**
   * Refresh session
   */
  const refreshSession = async () => {
    const result = await authService.refreshSession();
    
    if (!result.success) {
      dispatch({ type: AUTH_ACTIONS.SET_ERROR, payload: result.error });
    }
    
    return result;
  };

  /**
   * Clear error state
   */
  const clearError = () => {
    dispatch({ type: AUTH_ACTIONS.CLEAR_ERROR });
  };

  /**
   * Check if user has specific role/group
   */
  const hasRole = (role) => {
    return state.userGroups.includes(role);
  };

  /**
   * Check if user has any of the specified roles
   */
  const hasAnyRole = (roles) => {
    return roles.some(role => state.userGroups.includes(role));
  };

  // Context value
  const value = {
    // State
    user: state.user,
    isAuthenticated: state.isAuthenticated,
    isLoading: state.isLoading,
    error: state.error,
    mfaChallenge: state.mfaChallenge,
    userGroups: state.userGroups,
    
    // Actions
    signUp,
    confirmSignUp,
    resendConfirmationCode,
    signIn,
    confirmMFA,
    signOut,
    changePassword,
    forgotPassword,
    forgotPasswordSubmit,
    updateUserAttributes,
    deleteUser,
    getSession,
    refreshSession,
    clearError,
    checkAuthState,
    hasRole,
    hasAnyRole
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};

/**
 * Hook to use authentication context
 * Must be used within AuthProvider
 */
export const useAuth = () => {
  const context = useContext(AuthContext);
  
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  
  return context;
};

/**
 * Higher-order component for protected routes
 */
export const withAuth = (WrappedComponent, options = {}) => {
  const { 
    redirectTo = '/auth/login',
    requiredRoles = [],
    fallback = null 
  } = options;

  return function AuthenticatedComponent(props) {
    const { isAuthenticated, isLoading, hasAnyRole } = useAuth();
    const router = useRouter();

    useEffect(() => {
      if (!isLoading && !isAuthenticated) {
        router.push(redirectTo);
      } else if (!isLoading && isAuthenticated && requiredRoles.length > 0) {
        if (!hasAnyRole(requiredRoles)) {
          router.push('/unauthorized');
        }
      }
    }, [isAuthenticated, isLoading, router]);

    if (isLoading) {
      return fallback || <div>Loading...</div>;
    }

    if (!isAuthenticated) {
      return null;
    }

    if (requiredRoles.length > 0 && !hasAnyRole(requiredRoles)) {
      return <div>Unauthorized</div>;
    }

    return <WrappedComponent {...props} />;
  };
};

export default AuthContext;