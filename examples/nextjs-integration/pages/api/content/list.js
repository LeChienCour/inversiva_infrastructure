// API Route: List Content
// List user's content from S3 bucket

import { S3Client, ListObjectsV2Command } from '@aws-sdk/client-s3';
import { requireAuth } from '../../../auth/auth-middleware';

/**
 * API handler for listing user content
 * This endpoint returns a list of objects in the user's S3 prefix
 */
async function handler(req) {
  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { 
        status: 405,
        headers: { 'Content-Type': 'application/json' }
      }
    );
  }

  try {
    const { prefix = '', maxKeys = 100 } = await req.json();
    
    // Get user ID from authenticated request
    const userId = req.user.id;
    
    // Construct the full prefix - users can only list their own content or public content
    let fullPrefix;
    if (prefix.startsWith('public/')) {
      fullPrefix = prefix;
    } else {
      fullPrefix = prefix ? `users/${userId}/${prefix}` : `users/${userId}/`;
    }

    // Initialize S3 client
    const s3Client = new S3Client({
      region: process.env.NEXT_PUBLIC_AWS_REGION || 'us-east-1'
    });

    // List objects
    const command = new ListObjectsV2Command({
      Bucket: process.env.NEXT_PUBLIC_S3_CONTENT_BUCKET,
      Prefix: fullPrefix,
      MaxKeys: Math.min(maxKeys, 1000) // Limit to prevent abuse
    });

    const response = await s3Client.send(command);

    // Format the response
    const contents = (response.Contents || []).map(object => ({
      key: object.Key,
      name: object.Key.split('/').pop(), // Extract filename
      size: object.Size,
      lastModified: object.LastModified,
      etag: object.ETag,
      storageClass: object.StorageClass
    }));

    return new Response(
      JSON.stringify({
        contents,
        prefix: fullPrefix,
        isTruncated: response.IsTruncated,
        nextContinuationToken: response.NextContinuationToken,
        keyCount: response.KeyCount
      }),
      { 
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      }
    );

  } catch (error) {
    console.error('Error listing content:', error);
    
    return new Response(
      JSON.stringify({ 
        error: 'Failed to list content',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined
      }),
      { 
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      }
    );
  }
}

// Export the handler wrapped with authentication
export default requireAuth(handler);

/**
 * Example usage in frontend:
 * 
 * const listUserContent = async (prefix = '', maxKeys = 100) => {
 *   const session = await Auth.currentSession();
 *   const idToken = session.getIdToken().getJwtToken();
 *   
 *   const response = await fetch('/api/content/list', {
 *     method: 'POST',
 *     headers: {
 *       'Content-Type': 'application/json',
 *       'Authorization': `Bearer ${idToken}`
 *     },
 *     body: JSON.stringify({ prefix, maxKeys })
 *   });
 *   
 *   if (response.ok) {
 *     const data = await response.json();
 *     return data.contents;
 *   }
 *   
 *   throw new Error('Failed to list content');
 * };
 */