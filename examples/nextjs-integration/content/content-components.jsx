// Content Components for Presigned URL Integration
// Provides reusable components for content management

import React, { useState, useEffect } from 'react';
import contentService, { contentUtils } from './content-service';

/**
 * File Upload Component
 * Handles file uploads with progress tracking
 */
export const FileUpload = ({ 
  onUploadComplete, 
  onUploadError,
  allowedTypes = ['image/*', 'application/pdf'],
  maxSize = 10 * 1024 * 1024, // 10MB
  multiple = true,
  className = ''
}) => {
  const [dragOver, setDragOver] = useState(false);
  const [uploadProgress, setUploadProgress] = useState({});

  const handleFileUpload = async (files) => {
    const fileArray = Array.from(files);
    
    for (const file of fileArray) {
      // Validate file
      const validation = contentUtils.validateFile(file, allowedTypes, maxSize);
      
      if (!validation.isValid) {
        if (onUploadError) {
          onUploadError(`File ${file.name}: ${validation.errors.join(', ')}`);
        }
        continue;
      }

      const key = contentUtils.generateUserContentKey('user', file.name);
      
      setUploadProgress(prev => ({
        ...prev,
        [key]: { progress: 0, status: 'uploading', fileName: file.name }
      }));

      try {
        const result = await contentService.uploadFile(
          file,
          key,
          (progress) => {
            setUploadProgress(prev => ({
              ...prev,
              [key]: { ...prev[key], progress, status: 'uploading' }
            }));
          }
        );

        if (result.success) {
          setUploadProgress(prev => ({
            ...prev,
            [key]: { ...prev[key], progress: 100, status: 'completed' }
          }));
          
          if (onUploadComplete) {
            onUploadComplete({ key, fileName: file.name, size: file.size });
          }
          
          // Clear upload progress after delay
          setTimeout(() => {
            setUploadProgress(prev => {
              const newProgress = { ...prev };
              delete newProgress[key];
              return newProgress;
            });
          }, 2000);
        } else {
          setUploadProgress(prev => ({
            ...prev,
            [key]: { ...prev[key], progress: 0, status: 'error', error: result.error }
          }));
          
          if (onUploadError) {
            onUploadError(`Upload failed for ${file.name}: ${result.error}`);
          }
        }
      } catch (error) {
        console.error('Upload error:', error);
        setUploadProgress(prev => ({
          ...prev,
          [key]: { ...prev[key], progress: 0, status: 'error', error: error.message }
        }));
        
        if (onUploadError) {
          onUploadError(`Upload failed for ${file.name}: ${error.message}`);
        }
      }
    }
  };

  const handleDrop = (e) => {
    e.preventDefault();
    setDragOver(false);
    
    const files = e.dataTransfer.files;
    if (files.length > 0) {
      handleFileUpload(files);
    }
  };

  const handleDragOver = (e) => {
    e.preventDefault();
    setDragOver(true);
  };

  const handleDragLeave = (e) => {
    e.preventDefault();
    setDragOver(false);
  };

  const handleFileSelect = (e) => {
    const files = e.target.files;
    if (files.length > 0) {
      handleFileUpload(files);
    }
  };

  return (
    <div className={className}>
      {/* Upload Area */}
      <div
        className={`border-2 border-dashed rounded-lg p-8 text-center transition-colors ${
          dragOver
            ? 'border-blue-400 bg-blue-50'
            : 'border-gray-300 hover:border-gray-400'
        }`}
        onDrop={handleDrop}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
      >
        <svg
          className="mx-auto h-12 w-12 text-gray-400"
          stroke="currentColor"
          fill="none"
          viewBox="0 0 48 48"
        >
          <path
            d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02"
            strokeWidth={2}
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
        <div className="mt-4">
          <label htmlFor="file-upload" className="cursor-pointer">
            <span className="mt-2 block text-sm font-medium text-gray-900">
              Drop files here or click to upload
            </span>
            <input
              id="file-upload"
              name="file-upload"
              type="file"
              className="sr-only"
              multiple={multiple}
              accept={allowedTypes.join(',')}
              onChange={handleFileSelect}
            />
          </label>
          <p className="mt-2 text-xs text-gray-500">
            {allowedTypes.includes('image/*') && 'Images, '}
            {allowedTypes.includes('application/pdf') && 'PDF, '}
            up to {contentUtils.formatFileSize(maxSize)}
          </p>
        </div>
      </div>

      {/* Upload Progress */}
      {Object.keys(uploadProgress).length > 0 && (
        <div className="mt-4 space-y-2">
          {Object.entries(uploadProgress).map(([key, progress]) => (
            <div key={key} className="bg-white rounded-lg p-4 shadow border">
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium text-gray-900 truncate">
                  {progress.fileName}
                </span>
                <span className="text-sm text-gray-500">
                  {progress.status === 'uploading' && `${Math.round(progress.progress)}%`}
                  {progress.status === 'completed' && (
                    <span className="text-green-600">✓ Complete</span>
                  )}
                  {progress.status === 'error' && (
                    <span className="text-red-600">✗ Error</span>
                  )}
                </span>
              </div>
              {progress.status === 'uploading' && (
                <div className="mt-2 bg-gray-200 rounded-full h-2">
                  <div
                    className="bg-blue-600 h-2 rounded-full transition-all duration-300"
                    style={{ width: `${progress.progress}%` }}
                  ></div>
                </div>
              )}
              {progress.status === 'error' && (
                <p className="mt-2 text-sm text-red-600">{progress.error}</p>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

/**
 * Content Grid Component
 * Displays content items in a grid layout
 */
export const ContentGrid = ({ 
  content = [], 
  onContentClick, 
  onDownload, 
  onDelete,
  loading = false,
  className = ''
}) => {
  if (loading) {
    return (
      <div className={`text-center py-8 ${className}`}>
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto"></div>
        <p className="mt-2 text-gray-600">Loading content...</p>
      </div>
    );
  }

  if (content.length === 0) {
    return (
      <div className={`text-center py-8 ${className}`}>
        <svg
          className="mx-auto h-12 w-12 text-gray-400"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2m-9 0h10m-10 0a2 2 0 00-2 2v14a2 2 0 002 2h10a2 2 0 002-2V6a2 2 0 00-2-2m-5 4v6m-3-3h6"
          />
        </svg>
        <h3 className="mt-2 text-sm font-medium text-gray-900">No content</h3>
        <p className="mt-1 text-sm text-gray-500">
          Get started by uploading your first file.
        </p>
      </div>
    );
  }

  return (
    <div className={`grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 ${className}`}>
      {content.map((item) => (
        <ContentCard
          key={item.key}
          item={item}
          onClick={() => onContentClick && onContentClick(item)}
          onDownload={() => onDownload && onDownload(item)}
          onDelete={() => onDelete && onDelete(item)}
        />
      ))}
    </div>
  );
};

/**
 * Content Card Component
 * Individual content item display
 */
export const ContentCard = ({ item, onClick, onDownload, onDelete }) => {
  const isImage = item.contentType?.startsWith('image/');
  
  return (
    <div className="relative group bg-white border border-gray-200 rounded-lg hover:shadow-md transition-shadow cursor-pointer">
      <div 
        className="aspect-w-1 aspect-h-1 w-full overflow-hidden rounded-t-lg bg-gray-200"
        onClick={onClick}
      >
        {isImage ? (
          <div className="flex items-center justify-center h-32">
            <svg className="h-8 w-8 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
              <path fillRule="evenodd" d="M4 3a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V5a2 2 0 00-2-2H4zm12 12H4l4-8 3 6 2-4 3 6z" clipRule="evenodd" />
            </svg>
          </div>
        ) : (
          <div className="flex items-center justify-center h-32">
            <svg className="h-8 w-8 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
              <path fillRule="evenodd" d="M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4z" clipRule="evenodd" />
            </svg>
          </div>
        )}
      </div>
      
      <div className="p-4">
        <h4 className="text-sm font-medium text-gray-900 truncate">
          {item.name || item.key.split('/').pop()}
        </h4>
        <p className="text-sm text-gray-500">
          {item.size && contentUtils.formatFileSize(item.size)}
        </p>
        <p className="text-xs text-gray-400">
          {item.lastModified && new Date(item.lastModified).toLocaleDateString()}
        </p>
      </div>
      
      {/* Action buttons */}
      <div className="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity">
        <div className="flex space-x-1">
          {onDownload && (
            <button
              onClick={(e) => {
                e.stopPropagation();
                onDownload();
              }}
              className="p-1 bg-white rounded-full shadow-sm hover:bg-gray-50"
              title="Download"
            >
              <svg className="h-4 w-4 text-gray-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
            </button>
          )}
          {onDelete && (
            <button
              onClick={(e) => {
                e.stopPropagation();
                onDelete();
              }}
              className="p-1 bg-white rounded-full shadow-sm hover:bg-gray-50"
              title="Delete"
            >
              <svg className="h-4 w-4 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
              </svg>
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

/**
 * Content Modal Component
 * Modal for viewing content details
 */
export const ContentModal = ({ content, onClose, onDownload }) => {
  if (!content) return null;

  const isImage = content.contentType?.startsWith('image/');

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto">
      <div className="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div className="fixed inset-0 transition-opacity" onClick={onClose}>
          <div className="absolute inset-0 bg-gray-500 opacity-75"></div>
        </div>

        <div className="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full">
          <div className="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
            <div className="sm:flex sm:items-start">
              <div className="mt-3 text-center sm:mt-0 sm:text-left w-full">
                <h3 className="text-lg leading-6 font-medium text-gray-900 mb-4">
                  {content.name || content.key.split('/').pop()}
                </h3>
                
                {isImage && content.url ? (
                  <img
                    src={content.url}
                    alt={content.name}
                    className="w-full h-auto rounded-lg"
                  />
                ) : (
                  <div className="text-center py-8">
                    <svg className="mx-auto h-16 w-16 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4z" clipRule="evenodd" />
                    </svg>
                    <p className="mt-2 text-sm text-gray-600">
                      Preview not available for this file type
                    </p>
                  </div>
                )}
                
                {/* File details */}
                <div className="mt-4 text-sm text-gray-600">
                  {content.size && (
                    <p>Size: {contentUtils.formatFileSize(content.size)}</p>
                  )}
                  {content.contentType && (
                    <p>Type: {content.contentType}</p>
                  )}
                  {content.lastModified && (
                    <p>Modified: {new Date(content.lastModified).toLocaleString()}</p>
                  )}
                </div>
              </div>
            </div>
          </div>
          <div className="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
            {onDownload && (
              <button
                type="button"
                onClick={() => onDownload(content)}
                className="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-blue-600 text-base font-medium text-white hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 sm:ml-3 sm:w-auto sm:text-sm"
              >
                Download
              </button>
            )}
            <button
              type="button"
              onClick={onClose}
              className="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm"
            >
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};