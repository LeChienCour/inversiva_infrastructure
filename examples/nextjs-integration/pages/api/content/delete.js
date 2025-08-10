// API Route: Delete Content
// Delete user's content from S3 bucket

import { S3Client, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { requireAuth } from '../../../auth/auth-middleware';

/**
 * API handler for deleting user content
 * This endpoint deletes objects from the user's S3 prefix
 */
async function handler(req) {
  if (req.method !== 'DELETE') {
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

    // Validate that the user can delete this content
    const userId = req.user.id;
    if (!key.startsWith(`users/${userId}/`)) {
      return new Response(
        JSON.stringify({ error: 'Access denied - you can only delete your own content' }),
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

    // Delete the object
    const command = new DeleteObjectCommand({
      Bucket: process.env.NEXT_PUBLIC_S3_CONTENT_BUCKET,
      Key: key
    });

    await s3Client.send(command);

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Content deleted successfully',
        key
      }),
      { 
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      }
    );

  } catch (error) {
    console.error('Error deleting content:', error);
    
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
        error: 'Failed to delete content',
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
 * const deleteContent = async (key) => {
 *   const session = await Auth.currentSession();
 *   const idToken = session.getIdToken().getJwtToken();
 *   
 *   const response = await fetch('/api/content/delete', {
 *     method: 'DELETE',
 *     headers: {
 *       'Content-Type': 'application/json',
 *       'Authorization': `Bearer ${idToken}`
 *     },
 *     body: JSON.stringify({ key })
 *   });
 *   
 *   if (response.ok) {
 *     const result = await response.json();
 *     return result;
 *   }
 *   
 *   throw new Error('Failed to delete content');
 * };
 */