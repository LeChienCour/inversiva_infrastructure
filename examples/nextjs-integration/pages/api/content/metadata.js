// API Route: Content Metadata
// Get metadata for S3 objects without downloading them

import { S3Client, HeadObjectCommand } from '@aws-sdk/client-s3';
import { requireAuth } from '../../../auth/auth-middleware';

/**
 * API handler for getting content metadata
 * This endpoint returns metadata about S3 objects without downloading them
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
    const { key } = await req.json();
    
    if (!key) {
      return new Response(
        JSON.stringify({ error: 'Missing required parameter: key' }),
        { 
          status: 400,
          headers: { 'Content-Type': 'application/json' }
        }
      );
    }

    // Validate that the user can access this content
    // In a real implementation, you would check if the key belongs to the user
    // or if they have permission to access it
    const userId = req.user.id;
    if (!key.startsWith(`users/${userId}/`) && !key.startsWith('public/')) {
      return new Response(
        JSON.stringify({ error: 'Access denied' }),
        { 
          status: 403,
          headers: { 'Content-Type': 'application/json' }
        }
      );
    }

    // Initialize S3 client
    const s3Client = new S3Client({
      region: process.env.NEXT_PUBLIC_AWS_REGION || 'us-east-1'
    });

    // Get object metadata
    const command = new HeadObjectCommand({
      Bucket: process.env.NEXT_PUBLIC_S3_CONTENT_BUCKET,
      Key: key
    });

    const response = await s3Client.send(command);

    // Return metadata
    return new Response(
      JSON.stringify({
        key,
        contentType: response.ContentType,
        contentLength: response.ContentLength,
        lastModified: response.LastModified,
        etag: response.ETag,
        metadata: response.Metadata,
        storageClass: response.StorageClass,
        serverSideEncryption: response.ServerSideEncryption
      }),
      { 
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      }
    );

  } catch (error) {
    console.error('Error getting content metadata:', error);
    
    if (error.name === 'NoSuchKey') {
      return new Response(
        JSON.stringify({ error: 'Content not found' }),
        { 
          status: 404,
          headers: { 'Content-Type': 'application/json' }
        }
      );
    }

    return new Response(
      JSON.stringify({ 
        error: 'Failed to get content metadata',
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
 * const getContentMetadata = async (key) => {
 *   const session = await Auth.currentSession();
 *   const idToken = session.getIdToken().getJwtToken();
 *   
 *   const response = await fetch('/api/content/metadata', {
 *     method: 'POST',
 *     headers: {
 *       'Content-Type': 'application/json',
 *       'Authorization': `Bearer ${idToken}`
 *     },
 *     body: JSON.stringify({ key })
 *   });
 *   
 *   if (response.ok) {
 *     const metadata = await response.json();
 *     return metadata;
 *   }
 *   
 *   throw new Error('Failed to get metadata');
 * };
 */