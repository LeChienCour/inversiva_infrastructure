// API Route: AWS Credentials
// Exchanges Cognito ID token for temporary AWS credentials

import { CognitoIdentityClient, GetIdCommand, GetCredentialsForIdentityCommand } from '@aws-sdk/client-cognito-identity';
import jwt from 'jsonwebtoken';

/**
 * API handler for getting temporary AWS credentials
 * This endpoint exchanges a Cognito ID token for temporary AWS credentials
 * that can be used to access S3 and other AWS services
 */
export default async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    // Extract the ID token from the Authorization header
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Missing or invalid authorization header' });
    }

    const idToken = authHeader.replace('Bearer ', '');
    
    // Decode the token (in production, you should verify the signature)
    const decodedToken = jwt.decode(idToken);
    if (!decodedToken) {
      return res.status(401).json({ error: 'Invalid token' });
    }

    // Initialize Cognito Identity client
    const cognitoIdentityClient = new CognitoIdentityClient({
      region: process.env.NEXT_PUBLIC_AWS_REGION || 'us-east-1'
    });

    // Get identity ID from Cognito Identity Pool
    const getIdCommand = new GetIdCommand({
      IdentityPoolId: process.env.NEXT_PUBLIC_COGNITO_IDENTITY_POOL_ID,
      Logins: {
        [`cognito-idp.${process.env.NEXT_PUBLIC_AWS_REGION}.amazonaws.com/${process.env.NEXT_PUBLIC_COGNITO_USER_POOL_ID}`]: idToken
      }
    });

    const identityResponse = await cognitoIdentityClient.send(getIdCommand);
    const identityId = identityResponse.IdentityId;

    // Get temporary credentials for the identity
    const getCredentialsCommand = new GetCredentialsForIdentityCommand({
      IdentityId: identityId,
      Logins: {
        [`cognito-idp.${process.env.NEXT_PUBLIC_AWS_REGION}.amazonaws.com/${process.env.NEXT_PUBLIC_COGNITO_USER_POOL_ID}`]: idToken
      }
    });

    const credentialsResponse = await cognitoIdentityClient.send(getCredentialsCommand);
    const credentials = credentialsResponse.Credentials;

    // Return the temporary credentials
    res.status(200).json({
      AccessKeyId: credentials.AccessKeyId,
      SecretAccessKey: credentials.SecretKey,
      SessionToken: credentials.SessionToken,
      Expiration: credentials.Expiration,
      IdentityId: identityId
    });

  } catch (error) {
    console.error('Error getting AWS credentials:', error);
    res.status(500).json({ 
      error: 'Failed to get AWS credentials',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
}

/**
 * Example usage in frontend:
 * 
 * const getAWSCredentials = async () => {
 *   const session = await Auth.currentSession();
 *   const idToken = session.getIdToken().getJwtToken();
 *   
 *   const response = await fetch('/api/aws-credentials', {
 *     headers: {
 *       'Authorization': `Bearer ${idToken}`
 *     }
 *   });
 *   
 *   if (response.ok) {
 *     const credentials = await response.json();
 *     // Use credentials to configure AWS SDK clients
 *   }
 * };
 */