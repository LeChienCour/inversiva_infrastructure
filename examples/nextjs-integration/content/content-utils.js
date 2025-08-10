// Content Utility Functions
// Helper functions for content management and validation

/**
 * Generate a unique key for user content
 * @param {string} userId - User ID
 * @param {string} filename - Original filename
 * @returns {string} Unique S3 key
 */
export const generateUserContentKey = (userId, filename) => {
  const timestamp = Date.now();
  const randomSuffix = Math.random().toString(36).substring(2, 8);
  const sanitizedFilename = filename.replace(/[^a-zA-Z0-9.-]/g, '_');
  return `users/${userId}/${timestamp}_${randomSuffix}_${sanitizedFilename}`;
};

/**
 * Generate a key for shared/public content
 * @param {string} filename - Original filename
 * @param {string} category - Content category (optional)
 * @returns {string} Unique S3 key
 */
export const generatePublicContentKey = (filename, category = 'general') => {
  const timestamp = Date.now();
  const randomSuffix = Math.random().toString(36).substring(2, 8);
  const sanitizedFilename = filename.replace(/[^a-zA-Z0-9.-]/g, '_');
  return `public/${category}/${timestamp}_${randomSuffix}_${sanitizedFilename}`;
};

/**
 * Validate file type and size
 * @param {File} file - File to validate
 * @param {Array} allowedTypes - Array of allowed MIME types
 * @param {number} maxSize - Maximum file size in bytes
 * @returns {Object} Validation result
 */
export const validateFile = (file, allowedTypes = [], maxSize = 10 * 1024 * 1024) => {
  const errors = [];

  // Check file type
  if (allowedTypes.length > 0) {
    const isAllowed = allowedTypes.some(type => {
      if (type.endsWith('/*')) {
        // Handle wildcard types like 'image/*'
        const baseType = type.replace('/*', '');
        return file.type.startsWith(baseType);
      }
      return file.type === type;
    });

    if (!isAllowed) {
      errors.push(`File type ${file.type} is not allowed. Allowed types: ${allowedTypes.join(', ')}`);
    }
  }

  // Check file size
  if (file.size > maxSize) {
    errors.push(`File size ${formatFileSize(file.size)} exceeds maximum allowed size of ${formatFileSize(maxSize)}`);
  }

  // Check for empty files
  if (file.size === 0) {
    errors.push('File is empty');
  }

  return {
    isValid: errors.length === 0,
    errors
  };
};

/**
 * Format file size for display
 * @param {number} bytes - File size in bytes
 * @returns {string} Formatted file size
 */
export const formatFileSize = (bytes) => {
  if (bytes === 0) return '0 Bytes';
  
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
};

/**
 * Extract file extension from filename
 * @param {string} filename - Filename
 * @returns {string} File extension
 */
export const getFileExtension = (filename) => {
  return filename.slice((filename.lastIndexOf('.') - 1 >>> 0) + 2);
};

/**
 * Get MIME type from file extension
 * @param {string} extension - File extension
 * @returns {string} MIME type
 */
export const getMimeType = (extension) => {
  const mimeTypes = {
    // Images
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'svg': 'image/svg+xml',
    'bmp': 'image/bmp',
    'ico': 'image/x-icon',
    
    // Documents
    'pdf': 'application/pdf',
    'txt': 'text/plain',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    
    // Archives
    'zip': 'application/zip',
    'rar': 'application/x-rar-compressed',
    '7z': 'application/x-7z-compressed',
    'tar': 'application/x-tar',
    'gz': 'application/gzip',
    
    // Audio
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'ogg': 'audio/ogg',
    'flac': 'audio/flac',
    'aac': 'audio/aac',
    
    // Video
    'mp4': 'video/mp4',
    'avi': 'video/x-msvideo',
    'mov': 'video/quicktime',
    'wmv': 'video/x-ms-wmv',
    'flv': 'video/x-flv',
    'webm': 'video/webm',
    
    // Code
    'js': 'application/javascript',
    'json': 'application/json',
    'html': 'text/html',
    'css': 'text/css',
    'xml': 'application/xml',
    'csv': 'text/csv'
  };
  
  return mimeTypes[extension.toLowerCase()] || 'application/octet-stream';
};

/**
 * Check if file is an image
 * @param {string} mimeType - MIME type
 * @returns {boolean} True if file is an image
 */
export const isImage = (mimeType) => {
  return mimeType && mimeType.startsWith('image/');
};

/**
 * Check if file is a video
 * @param {string} mimeType - MIME type
 * @returns {boolean} True if file is a video
 */
export const isVideo = (mimeType) => {
  return mimeType && mimeType.startsWith('video/');
};

/**
 * Check if file is an audio file
 * @param {string} mimeType - MIME type
 * @returns {boolean} True if file is an audio file
 */
export const isAudio = (mimeType) => {
  return mimeType && mimeType.startsWith('audio/');
};

/**
 * Check if file is a document
 * @param {string} mimeType - MIME type
 * @returns {boolean} True if file is a document
 */
export const isDocument = (mimeType) => {
  const documentTypes = [
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'text/plain'
  ];
  
  return mimeType && documentTypes.includes(mimeType);
};

/**
 * Get file icon based on MIME type
 * @param {string} mimeType - MIME type
 * @returns {string} Icon name or emoji
 */
export const getFileIcon = (mimeType) => {
  if (isImage(mimeType)) return '🖼️';
  if (isVideo(mimeType)) return '🎥';
  if (isAudio(mimeType)) return '🎵';
  if (mimeType === 'application/pdf') return '📄';
  if (isDocument(mimeType)) return '📝';
  if (mimeType && mimeType.includes('zip')) return '📦';
  return '📁';
};

/**
 * Generate thumbnail URL for images
 * @param {string} originalUrl - Original image URL
 * @param {number} width - Thumbnail width
 * @param {number} height - Thumbnail height
 * @returns {string} Thumbnail URL
 */
export const generateThumbnailUrl = (originalUrl, width = 200, height = 200) => {
  // This would typically use a service like AWS Lambda@Edge or CloudFront Functions
  // to generate thumbnails on-the-fly. For this example, we'll return the original URL.
  return originalUrl;
};

/**
 * Parse S3 key to extract metadata
 * @param {string} key - S3 object key
 * @returns {Object} Parsed metadata
 */
export const parseS3Key = (key) => {
  const parts = key.split('/');
  const filename = parts[parts.length - 1];
  const [timestamp, randomSuffix, ...nameParts] = filename.split('_');
  const originalName = nameParts.join('_');
  
  return {
    key,
    filename,
    originalName,
    timestamp: parseInt(timestamp),
    randomSuffix,
    path: parts.slice(0, -1).join('/'),
    category: parts[0],
    userId: parts[1] || null
  };
};

/**
 * Create a download filename from S3 key
 * @param {string} key - S3 object key
 * @returns {string} Download filename
 */
export const getDownloadFilename = (key) => {
  const parsed = parseS3Key(key);
  return parsed.originalName || parsed.filename;
};

/**
 * Validate content key format
 * @param {string} key - S3 object key
 * @returns {boolean} True if key format is valid
 */
export const isValidContentKey = (key) => {
  // Basic validation for our key format
  const keyPattern = /^(users|public)\/[^\/]+\/\d+_[a-z0-9]+_.+$/;
  return keyPattern.test(key);
};

/**
 * Generate presigned URL expiration time
 * @param {string} operation - Operation type (download, upload, delete)
 * @returns {number} Expiration time in seconds
 */
export const getPresignedUrlExpiry = (operation) => {
  const expiryTimes = {
    download: 15 * 60, // 15 minutes
    upload: 30 * 60,   // 30 minutes
    delete: 5 * 60     // 5 minutes
  };
  
  return expiryTimes[operation] || 15 * 60;
};

/**
 * Create a content metadata object
 * @param {File} file - File object
 * @param {string} key - S3 key
 * @returns {Object} Content metadata
 */
export const createContentMetadata = (file, key) => {
  return {
    key,
    name: file.name,
    size: file.size,
    type: file.type,
    lastModified: new Date(file.lastModified).toISOString(),
    uploadedAt: new Date().toISOString(),
    extension: getFileExtension(file.name),
    isImage: isImage(file.type),
    isVideo: isVideo(file.type),
    isAudio: isAudio(file.type),
    isDocument: isDocument(file.type)
  };
};

/**
 * Filter content by type
 * @param {Array} content - Array of content items
 * @param {string} type - Content type filter
 * @returns {Array} Filtered content
 */
export const filterContentByType = (content, type) => {
  if (!type || type === 'all') return content;
  
  return content.filter(item => {
    switch (type) {
      case 'images':
        return isImage(item.contentType || item.type);
      case 'videos':
        return isVideo(item.contentType || item.type);
      case 'audio':
        return isAudio(item.contentType || item.type);
      case 'documents':
        return isDocument(item.contentType || item.type);
      default:
        return true;
    }
  });
};

/**
 * Sort content by various criteria
 * @param {Array} content - Array of content items
 * @param {string} sortBy - Sort criteria
 * @param {string} order - Sort order (asc, desc)
 * @returns {Array} Sorted content
 */
export const sortContent = (content, sortBy = 'name', order = 'asc') => {
  const sorted = [...content].sort((a, b) => {
    let aValue, bValue;
    
    switch (sortBy) {
      case 'name':
        aValue = (a.name || a.key).toLowerCase();
        bValue = (b.name || b.key).toLowerCase();
        break;
      case 'size':
        aValue = a.size || 0;
        bValue = b.size || 0;
        break;
      case 'date':
        aValue = new Date(a.lastModified || a.uploadedAt || 0);
        bValue = new Date(b.lastModified || b.uploadedAt || 0);
        break;
      case 'type':
        aValue = (a.contentType || a.type || '').toLowerCase();
        bValue = (b.contentType || b.type || '').toLowerCase();
        break;
      default:
        return 0;
    }
    
    if (aValue < bValue) return order === 'asc' ? -1 : 1;
    if (aValue > bValue) return order === 'asc' ? 1 : -1;
    return 0;
  });
  
  return sorted;
};

/**
 * Search content by name or metadata
 * @param {Array} content - Array of content items
 * @param {string} query - Search query
 * @returns {Array} Filtered content
 */
export const searchContent = (content, query) => {
  if (!query) return content;
  
  const lowerQuery = query.toLowerCase();
  
  return content.filter(item => {
    const name = (item.name || item.key || '').toLowerCase();
    const type = (item.contentType || item.type || '').toLowerCase();
    const extension = getFileExtension(item.name || item.key || '').toLowerCase();
    
    return name.includes(lowerQuery) || 
           type.includes(lowerQuery) || 
           extension.includes(lowerQuery);
  });
};

// Export all utilities as default object
export default {
  generateUserContentKey,
  generatePublicContentKey,
  validateFile,
  formatFileSize,
  getFileExtension,
  getMimeType,
  isImage,
  isVideo,
  isAudio,
  isDocument,
  getFileIcon,
  generateThumbnailUrl,
  parseS3Key,
  getDownloadFilename,
  isValidContentKey,
  getPresignedUrlExpiry,
  createContentMetadata,
  filterContentByType,
  sortContent,
  searchContent
};