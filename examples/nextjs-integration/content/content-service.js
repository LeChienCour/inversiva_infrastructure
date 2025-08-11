// Content Service for S3 Presigned URLs
// Handles secure content access through presigned URLs

import { S3Client, GetObjectCommand, PutObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import authService from '../auth/auth-service';

/**
 * Content Service Class
 * Provides methods for secure content access using S3 presigned URLs
 */
class ContentService {
  constructor() {
    this.s3Client = null;
    this.config = null;
    this.isConfigured = false;
  }

  /**
   * Configure the content service
   * @param {Object} config - Configuration object
   */
  configure(config) {
    this.config = config;
    
    // Initialize S3 client with temporary credentials from Cognito
    this.s3Client = new S3Client({
      region: config.region,
      credentials: async () => {
        const session = await authService.getSession();
        if (!session.success) {
          throw new Error('User not authenticated');
        }
        
        // In a real implementation, you would use the Cognito Identity Pool
        // to get temporary AWS credentials. For this example, we'll use
        // a backend API endpoint that handles the credential exchange.
        const response = await fetch('/api/aws-credentials', {
          headers: {
            'Authorization': `Bearer ${session.idToken}`
          }
        });
        
        if (!response.ok) {
          throw new Error('Failed to get AWS credentials');
        }
        
        const credentials = await response.json();
        return {
          accessKeyId: credentials.AccessKeyId,
          secretAccessKey: credentials.SecretAccessKey,
          sessionToken: credentials.SessionToken
        };
      }
    });
    
    this.isConfigured = true;
  }

  /**
   * Check if the service is properly configured
   */
  _checkConfiguration() {
    if (!this.isConfigured) {
      throw new Error('ContentService not configured. Call configure() first.');
    }
  }

  /**
   * Check if user is authenticated
   */
  async _checkAuthentication() {
    const isAuthenticated = await authService.isAuthenticated();
    if (!isAuthenticated) {
      throw new Error('User must be authenticated to access content');
    }
  }

  /**
   * Generate presigned URL for downloading content
   * @param {string} key - S3 object key
   * @param {number} expiresIn - URL expiration time in seconds (default: 900 = 15 minutes)
   * @returns {Promise<Object>} Result object with presigned URL
   */
  async getDownloadUrl(key, expiresIn = 900) {
    this._checkConfiguration();
    await this._checkAuthentication();

    try {
      const command = new GetObjectCommand({
        Bucket: this.config.contentBucket,
        Key: key
      });

      const presignedUrl = await getSignedUrl(this.s3Client, command, {
        expiresIn
      });

      return {
        success: true,
        url: presignedUrl,
        expiresIn,
        key
      };
    } catch (error) {
      console.error('Error generating download URL:', error);
      return {
        success: false,
        error: error.message,
        key
      };
    }
  }

  /**
   * Generate presigned URL for uploading content
   * @param {string} key - S3 object key
   * @param {string} contentType - MIME type of the content
   * @param {number} expiresIn - URL expiration time in seconds (default: 900 = 15 minutes)
   * @returns {Promise<Object>} Result object with presigned URL
   */
  async getUploadUrl(key, contentType, expiresIn = 900) {
    this._checkConfiguration();
    await this._checkAuthentication();

    try {
      const command = new PutObjectCommand({
        Bucket: this.config.contentBucket,
        Key: key,
        ContentType: contentType
      });

      const presignedUrl = await getSignedUrl(this.s3Client, command, {
        expiresIn
      });

      return {
        success: true,
        url: presignedUrl,
        expiresIn,
        key,
        contentType
      };
    } catch (error) {
      console.error('Error generating upload URL:', error);
      return {
        success: false,
        error: error.message,
        key
      };
    }
  }

  /**
   * Generate presigned URL for deleting content
   * @param {string} key - S3 object key
   * @param {number} expiresIn - URL expiration time in seconds (default: 300 = 5 minutes)
   * @returns {Promise<Object>} Result object with presigned URL
   */
  async getDeleteUrl(key, expiresIn = 300) {
    this._checkConfiguration();
    await this._checkAuthentication();

    try {
      const command = new DeleteObjectCommand({
        Bucket: this.config.contentBucket,
        Key: key
      });

      const presignedUrl = await getSignedUrl(this.s3Client, command, {
        expiresIn
      });

      return {
        success: true,
        url: presignedUrl,
        expiresIn,
        key
      };
    } catch (error) {
      console.error('Error generating delete URL:', error);
      return {
        success: false,
        error: error.message,
        key
      };
    }
  }

  /**
   * Request multiple presigned URLs for batch operations
   * @param {Array} requests - Array of request objects {key, operation, contentType?, expiresIn?}
   * @returns {Promise<Object>} Result object with array of presigned URLs
   */
  async getBatchUrls(requests) {
    this._checkConfiguration();
    await this._checkAuthentication();

    const results = [];
    
    for (const request of requests) {
      const { key, operation, contentType, expiresIn } = request;
      
      let result;
      switch (operation) {
        case 'download':
          result = await this.getDownloadUrl(key, expiresIn);
          break;
        case 'upload':
          result = await this.getUploadUrl(key, contentType, expiresIn);
          break;
        case 'delete':
          result = await this.getDeleteUrl(key, expiresIn);
          break;
        default:
          result = {
            success: false,
            error: `Invalid operation: ${operation}`,
            key
          };
      }
      
      results.push(result);
    }

    return {
      success: true,
      results
    };
  }

  /**
   * Upload file using presigned URL
   * @param {File} file - File object to upload
   * @param {string} key - S3 object key
   * @param {Function} onProgress - Progress callback function
   * @returns {Promise<Object>} Result object with upload status
   */
  async uploadFile(file, key, onProgress = null) {
    try {
      // Get presigned URL for upload
      const urlResult = await this.getUploadUrl(key, file.type);
      
      if (!urlResult.success) {
        return urlResult;
      }

      // Create XMLHttpRequest for progress tracking
      return new Promise((resolve, reject) => {
        const xhr = new XMLHttpRequest();
        
        xhr.upload.addEventListener('progress', (event) => {
          if (event.lengthComputable && onProgress) {
            const percentComplete = (event.loaded / event.total) * 100;
            onProgress(percentComplete);
          }
        });

        xhr.addEventListener('load', () => {
          if (xhr.status === 200) {
            resolve({
              success: true,
              key,
              message: 'File uploaded successfully'
            });
          } else {
            resolve({
              success: false,
              error: `Upload failed with status: ${xhr.status}`,
              key
            });
          }
        });

        xhr.addEventListener('error', () => {
          resolve({
            success: false,
            error: 'Upload failed due to network error',
            key
          });
        });

        xhr.open('PUT', urlResult.url);
        xhr.setRequestHeader('Content-Type', file.type);
        xhr.send(file);
      });
    } catch (error) {
      console.error('Error uploading file:', error);
      return {
        success: false,
        error: error.message,
        key
      };
    }
  }

  /**
   * Download file using presigned URL
   * @param {string} key - S3 object key
   * @param {string} filename - Desired filename for download
   * @returns {Promise<Object>} Result object with download status
   */
  async downloadFile(key, filename = null) {
    try {
      // Get presigned URL for download
      const urlResult = await this.getDownloadUrl(key);
      
      if (!urlResult.success) {
        return urlResult;
      }

      // Create temporary link and trigger download
      const link = document.createElement('a');
      link.href = urlResult.url;
      link.download = filename || key.split('/').pop();
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);

      return {
        success: true,
        key,
        message: 'Download initiated successfully'
      };
    } catch (error) {
      console.error('Error downloading file:', error);
      return {
        success: false,
        error: error.message,
        key
      };
    }
  }

  /**
   * Get content metadata without downloading
   * @param {string} key - S3 object key
   * @returns {Promise<Object>} Result object with metadata
   */
  async getContentMetadata(key) {
    this._checkConfiguration();
    await this._checkAuthentication();

    try {
      // This would typically be handled by a backend API
      const response = await fetch('/api/content/metadata', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${(await authService.getSession()).idToken}`
        },
        body: JSON.stringify({ key })
      });

      if (!response.ok) {
        throw new Error(`Failed to get metadata: ${response.statusText}`);
      }

      const metadata = await response.json();
      
      return {
        success: true,
        metadata,
        key
      };
    } catch (error) {
      console.error('Error getting content metadata:', error);
      return {
        success: false,
        error: error.message,
        key
      };
    }
  }

  /**
   * List user's content
   * @param {string} prefix - Key prefix to filter content
   * @param {number} maxKeys - Maximum number of keys to return
   * @returns {Promise<Object>} Result object with content list
   */
  async listContent(prefix = '', maxKeys = 100) {
    this._checkConfiguration();
    await this._checkAuthentication();

    try {
      // This would typically be handled by a backend API
      const response = await fetch('/api/content/list', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${(await authService.getSession()).idToken}`
        },
        body: JSON.stringify({ prefix, maxKeys })
      });

      if (!response.ok) {
        throw new Error(`Failed to list content: ${response.statusText}`);
      }

      const contentList = await response.json();
      
      return {
        success: true,
        contents: contentList.contents || [],
        prefix
      };
    } catch (error) {
      console.error('Error listing content:', error);
      return {
        success: false,
        error: error.message,
        prefix
      };
    }
  }
}

// Create and export a singleton instance
const contentService = new ContentService();

export default contentService;

// Export the class for custom instances if needed
export { ContentService };

// Helper function to get configuration from environment variables
export const getContentConfigFromEnv = () => ({
  region: process.env.NEXT_PUBLIC_AWS_REGION,
  contentBucket: process.env.NEXT_PUBLIC_S3_CONTENT_BUCKET
});

// Utility functions for content operations
export const contentUtils = {
  /**
   * Generate a unique key for user content
   * @param {string} userId - User ID
   * @param {string} filename - Original filename
   * @returns {string} Unique S3 key
   */
  generateUserContentKey(userId, filename) {
    const timestamp = Date.now();
    const randomSuffix = Math.random().toString(36).substring(2, 8);
    const sanitizedFilename = filename.replace(/[^a-zA-Z0-9.-]/g, '_');
    return `users/${userId}/${timestamp}_${randomSuffix}_${sanitizedFilename}`;
  },

  /**
   * Validate file type and size
   * @param {File} file - File to validate
   * @param {Array} allowedTypes - Array of allowed MIME types
   * @param {number} maxSize - Maximum file size in bytes
   * @returns {Object} Validation result
   */
  validateFile(file, allowedTypes = [], maxSize = 10 * 1024 * 1024) {
    const errors = [];

    if (allowedTypes.length > 0 && !allowedTypes.includes(file.type)) {
      errors.push(`File type ${file.type} is not allowed`);
    }

    if (file.size > maxSize) {
      errors.push(`File size ${file.size} exceeds maximum allowed size of ${maxSize} bytes`);
    }

    return {
      isValid: errors.length === 0,
      errors
    };
  },

  /**
   * Format file size for display
   * @param {number} bytes - File size in bytes
   * @returns {string} Formatted file size
   */
  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  },

  /**
   * Extract file extension from filename
   * @param {string} filename - Filename
   * @returns {string} File extension
   */
  getFileExtension(filename) {
    return filename.slice((filename.lastIndexOf('.') - 1 >>> 0) + 2);
  },

  /**
   * Get MIME type from file extension
   * @param {string} extension - File extension
   * @returns {string} MIME type
   */
  getMimeType(extension) {
    const mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'pdf': 'application/pdf',
      'txt': 'text/plain',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'mp4': 'video/mp4',
      'mp3': 'audio/mpeg'
    };
    
    return mimeTypes[extension.toLowerCase()] || 'application/octet-stream';
  }
};