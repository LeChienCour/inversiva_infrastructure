// AWS Amplify Configuration
// Centralized configuration for AWS services integration

/**
 * Get Amplify configuration from environment variables
 * @returns {Object} Amplify configuration object
 */
export const getAmplifyConfig = () => ({
  Auth: {
    // AWS Region
    region: process.env.NEXT_PUBLIC_AWS_REGION || 'us-east-1',
    
    // Cognito User Pool configuration
    userPoolId: process.env.NEXT_PUBLIC_COGNITO_USER_POOL_ID,
    userPoolWebClientId: process.env.NEXT_PUBLIC_COGNITO_USER_POOL_CLIENT_ID,
    
    // Cognito Identity Pool configuration (for AWS resource access)
    identityPoolId: process.env.NEXT_PUBLIC_COGNITO_IDENTITY_POOL_ID,
    
    // OAuth configuration
    oauth: {
      domain: process.env.NEXT_PUBLIC_COGNITO_DOMAIN,
      scope: ['email', 'openid', 'profile', 'aws.cognito.signin.user.admin'],
      redirectSignIn: process.env.NEXT_PUBLIC_OAUTH_REDIRECT_URI || 
                     (typeof window !== 'undefined' ? `${window.location.origin}/auth/callback` : 'http://localhost:3000/auth/callback'),
      redirectSignOut: process.env.NEXT_PUBLIC_OAUTH_LOGOUT_URI || 
                      (typeof window !== 'undefined' ? `${window.location.origin}/auth/logout` : 'http://localhost:3000/auth/logout'),
      responseType: 'code'
    },
    
    // Authentication flow type
    authenticationFlowType: 'USER_SRP_AUTH',
    
    // Password policy (for client-side validation)
    passwordPolicy: {
      minimumLength: 8,
      requireLowercase: true,
      requireUppercase: true,
      requireNumbers: true,
      requireSymbols: true
    }
  },
  
  // Storage configuration (for S3 access)
  Storage: {
    AWSS3: {
      bucket: process.env.NEXT_PUBLIC_S3_CONTENT_BUCKET,
      region: process.env.NEXT_PUBLIC_AWS_REGION || 'us-east-1',
      
      // Custom prefix for user files
      customPrefix: {
        public: 'public/',
        protected: 'protected/{identityId}/',
        private: 'private/{identityId}/'
      },
      
      // Track uploads
      track: true
    }
  },
  
  // API configuration (if using API Gateway)
  API: {
    endpoints: [
      {
        name: 'api',
        endpoint: process.env.NEXT_PUBLIC_API_BASE_URL,
        region: process.env.NEXT_PUBLIC_AWS_REGION || 'us-east-1',
        custom_header: async () => {
          // Add custom headers if needed
          return {};
        }
      }
    ]
  },
  
  // Analytics configuration (optional)
  Analytics: {
    // Disable analytics by default
    disabled: true,
    
    // Amazon Pinpoint configuration (if enabled)
    AWSPinpoint: {
      appId: process.env.NEXT_PUBLIC_PINPOINT_APP_ID,
      region: process.env.NEXT_PUBLIC_AWS_REGION || 'us-east-1',
      mandatorySignIn: false
    }
  }
});

/**
 * Environment-specific configuration overrides
 */
export const getEnvironmentConfig = () => {
  const environment = process.env.NEXT_PUBLIC_ENVIRONMENT || 'development';
  
  const configs = {
    development: {
      // Development-specific overrides
      Auth: {
        oauth: {
          redirectSignIn: 'http://localhost:3000/auth/callback',
          redirectSignOut: 'http://localhost:3000/auth/logout'
        }
      },
      // Enable more verbose logging in development
      logging: {
        level: 'DEBUG'
      }
    },
    
    staging: {
      // Staging-specific overrides
      Auth: {
        oauth: {
          redirectSignIn: `https://staging.${process.env.NEXT_PUBLIC_CUSTOM_DOMAIN}/auth/callback`,
          redirectSignOut: `https://staging.${process.env.NEXT_PUBLIC_CUSTOM_DOMAIN}/auth/logout`
        }
      }
    },
    
    production: {
      // Production-specific overrides
      Auth: {
        oauth: {
          redirectSignIn: `https://${process.env.NEXT_PUBLIC_CUSTOM_DOMAIN}/auth/callback`,
          redirectSignOut: `https://${process.env.NEXT_PUBLIC_CUSTOM_DOMAIN}/auth/logout`
        }
      },
      // Disable logging in production
      logging: {
        level: 'ERROR'
      }
    }
  };
  
  return configs[environment] || configs.development;
};

/**
 * Merge base configuration with environment-specific overrides
 * @returns {Object} Complete Amplify configuration
 */
export const getCompleteAmplifyConfig = () => {
  const baseConfig = getAmplifyConfig();
  const envConfig = getEnvironmentConfig();
  
  // Deep merge configurations
  return mergeDeep(baseConfig, envConfig);
};

/**
 * Deep merge utility function
 * @param {Object} target - Target object
 * @param {Object} source - Source object
 * @returns {Object} Merged object
 */
function mergeDeep(target, source) {
  const output = Object.assign({}, target);
  
  if (isObject(target) && isObject(source)) {
    Object.keys(source).forEach(key => {
      if (isObject(source[key])) {
        if (!(key in target)) {
          Object.assign(output, { [key]: source[key] });
        } else {
          output[key] = mergeDeep(target[key], source[key]);
        }
      } else {
        Object.assign(output, { [key]: source[key] });
      }
    });
  }
  
  return output;
}

/**
 * Check if value is an object
 * @param {*} item - Item to check
 * @returns {boolean} True if item is an object
 */
function isObject(item) {
  return item && typeof item === 'object' && !Array.isArray(item);
}

/**
 * Validate required configuration values
 * @param {Object} config - Configuration object
 * @returns {Object} Validation result
 */
export const validateConfig = (config) => {
  const required = [
    'Auth.region',
    'Auth.userPoolId',
    'Auth.userPoolWebClientId'
  ];
  
  const missing = [];
  
  required.forEach(path => {
    const value = getNestedValue(config, path);
    if (!value) {
      missing.push(path);
    }
  });
  
  return {
    isValid: missing.length === 0,
    missing,
    warnings: []
  };
};

/**
 * Get nested object value by path
 * @param {Object} obj - Object to search
 * @param {string} path - Dot-separated path
 * @returns {*} Value at path
 */
function getNestedValue(obj, path) {
  return path.split('.').reduce((current, key) => current && current[key], obj);
}

/**
 * Configuration for different authentication flows
 */
export const authFlowConfigs = {
  // Standard username/password flow
  USER_SRP_AUTH: {
    authenticationFlowType: 'USER_SRP_AUTH',
    signUpVerificationMethod: 'email'
  },
  
  // Custom authentication flow
  CUSTOM_AUTH: {
    authenticationFlowType: 'CUSTOM_AUTH',
    signUpVerificationMethod: 'email'
  },
  
  // Admin-only authentication (for server-side)
  ADMIN_NO_SRP_AUTH: {
    authenticationFlowType: 'ADMIN_NO_SRP_AUTH',
    signUpVerificationMethod: 'email'
  }
};

/**
 * Get S3 configuration for content service
 * @returns {Object} S3 configuration
 */
export const getS3Config = () => ({
  region: process.env.NEXT_PUBLIC_AWS_REGION || 'us-east-1',
  contentBucket: process.env.NEXT_PUBLIC_S3_CONTENT_BUCKET,
  websiteBucket: process.env.NEXT_PUBLIC_S3_WEBSITE_BUCKET,
  
  // Presigned URL configuration
  presignedUrl: {
    expiresIn: {
      download: 15 * 60, // 15 minutes
      upload: 30 * 60,   // 30 minutes
      delete: 5 * 60     // 5 minutes
    }
  },
  
  // Upload constraints
  upload: {
    maxFileSize: 10 * 1024 * 1024, // 10MB
    allowedTypes: [
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/webp',
      'application/pdf',
      'text/plain'
    ],
    maxFiles: 10 // Maximum files per upload batch
  }
});

/**
 * Get CloudFront configuration
 * @returns {Object} CloudFront configuration
 */
export const getCloudFrontConfig = () => ({
  distributionId: process.env.NEXT_PUBLIC_CLOUDFRONT_DISTRIBUTION_ID,
  domainName: process.env.NEXT_PUBLIC_CLOUDFRONT_DOMAIN,
  customDomain: process.env.NEXT_PUBLIC_CUSTOM_DOMAIN,
  
  // Cache invalidation settings
  invalidation: {
    enabled: true,
    paths: ['/*'],
    maxRetries: 3
  }
});

/**
 * Export default configuration
 */
export default getCompleteAmplifyConfig();