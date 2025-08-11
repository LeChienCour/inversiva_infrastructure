#!/usr/bin/env node

// Node.js deployment script for Next.js build artifacts to S3
// Uploads the Next.js build output to the S3 website bucket

const fs = require('fs');
const path = require('path');
const { S3Client, PutObjectCommand, DeleteObjectCommand, ListObjectsV2Command } = require('@aws-sdk/client-s3');
const { CloudFrontClient, CreateInvalidationCommand } = require('@aws-sdk/client-cloudfront');
const mime = require('mime-types');
const crypto = require('crypto');

/**
 * Deployment Configuration
 */
const config = {
  // AWS Configuration
  region: process.env.AWS_REGION || 'us-east-1',
  websiteBucket: process.env.S3_WEBSITE_BUCKET,
  cloudfrontDistributionId: process.env.CLOUDFRONT_DISTRIBUTION_ID,
  
  // Build Configuration
  buildDir: process.env.BUILD_DIR || '.next/out',
  environment: process.env.ENVIRONMENT || 'dev',
  
  // Deployment Options
  deleteOldFiles: process.env.DELETE_OLD_FILES === 'true',
  createInvalidation: process.env.CREATE_INVALIDATION !== 'false',
  dryRun: process.env.DRY_RUN === 'true',
  
  // Cache Control Settings
  cacheControl: {
    html: 'public, max-age=0, s-maxage=86400, must-revalidate',
    assets: 'public, max-age=31536000, immutable',
    api: 'public, max-age=0, s-maxage=60',
    default: 'public, max-age=86400'
  }
};

/**
 * Deployment Class
 */
class NextJSDeployer {
  constructor() {
    this.s3Client = new S3Client({ region: config.region });
    this.cloudfrontClient = new CloudFrontClient({ region: config.region });
    this.uploadedFiles = [];
    this.errors = [];
  }

  /**
   * Validate configuration
   */
  validateConfig() {
    const required = ['websiteBucket'];
    const missing = required.filter(key => !config[key]);
    
    if (missing.length > 0) {
      throw new Error(`Missing required configuration: ${missing.join(', ')}`);
    }

    if (!fs.existsSync(config.buildDir)) {
      throw new Error(`Build directory not found: ${config.buildDir}`);
    }

    console.log('✅ Configuration validated');
  }

  /**
   * Get all files in build directory recursively
   */
  getAllFiles(dir, baseDir = dir) {
    const files = [];
    const items = fs.readdirSync(dir);

    for (const item of items) {
      const fullPath = path.join(dir, item);
      const stat = fs.statSync(fullPath);

      if (stat.isDirectory()) {
        files.push(...this.getAllFiles(fullPath, baseDir));
      } else {
        const relativePath = path.relative(baseDir, fullPath);
        files.push({
          localPath: fullPath,
          s3Key: relativePath.replace(/\\/g, '/'), // Normalize path separators
          size: stat.size,
          lastModified: stat.mtime
        });
      }
    }

    return files;
  }

  /**
   * Get appropriate cache control header for file
   */
  getCacheControl(s3Key) {
    if (s3Key.endsWith('.html')) {
      return config.cacheControl.html;
    }
    
    if (s3Key.includes('/_next/static/')) {
      return config.cacheControl.assets;
    }
    
    if (s3Key.startsWith('api/')) {
      return config.cacheControl.api;
    }
    
    return config.cacheControl.default;
  }

  /**
   * Get content type for file
   */
  getContentType(s3Key) {
    const mimeType = mime.lookup(s3Key);
    
    // Special handling for certain file types
    if (s3Key.endsWith('.html')) {
      return 'text/html; charset=utf-8';
    }
    
    if (s3Key.endsWith('.js')) {
      return 'application/javascript; charset=utf-8';
    }
    
    if (s3Key.endsWith('.css')) {
      return 'text/css; charset=utf-8';
    }
    
    return mimeType || 'application/octet-stream';
  }

  /**
   * Calculate file hash for comparison
   */
  calculateFileHash(filePath) {
    const fileBuffer = fs.readFileSync(filePath);
    return crypto.createHash('md5').update(fileBuffer).digest('hex');
  }

  /**
   * Check if file needs to be uploaded
   */
  async shouldUploadFile(file) {
    try {
      const command = new ListObjectsV2Command({
        Bucket: config.websiteBucket,
        Prefix: file.s3Key,
        MaxKeys: 1
      });

      const response = await this.s3Client.send(command);
      
      if (!response.Contents || response.Contents.length === 0) {
        return true; // File doesn't exist, upload it
      }

      const s3Object = response.Contents[0];
      const localHash = this.calculateFileHash(file.localPath);
      
      // Compare ETags (S3 uses MD5 hash as ETag for simple uploads)
      const s3Hash = s3Object.ETag.replace(/"/g, '');
      
      return localHash !== s3Hash;
    } catch (error) {
      console.warn(`⚠️  Could not check existing file ${file.s3Key}: ${error.message}`);
      return true; // Upload if we can't check
    }
  }

  /**
   * Upload a single file to S3
   */
  async uploadFile(file) {
    try {
      const fileContent = fs.readFileSync(file.localPath);
      
      const command = new PutObjectCommand({
        Bucket: config.websiteBucket,
        Key: file.s3Key,
        Body: fileContent,
        ContentType: this.getContentType(file.s3Key),
        CacheControl: this.getCacheControl(file.s3Key),
        Metadata: {
          'deployment-environment': config.environment,
          'deployment-timestamp': new Date().toISOString(),
          'original-filename': path.basename(file.localPath)
        }
      });

      if (!config.dryRun) {
        await this.s3Client.send(command);
      }

      this.uploadedFiles.push(file.s3Key);
      console.log(`✅ Uploaded: ${file.s3Key} (${this.formatFileSize(file.size)})`);
      
      return true;
    } catch (error) {
      console.error(`❌ Failed to upload ${file.s3Key}: ${error.message}`);
      this.errors.push({ file: file.s3Key, error: error.message });
      return false;
    }
  }

  /**
   * Delete old files from S3 that are not in the current build
   */
  async deleteOldFiles(currentFiles) {
    if (!config.deleteOldFiles) {
      console.log('🔄 Skipping deletion of old files');
      return;
    }

    try {
      console.log('🔄 Checking for old files to delete...');
      
      const command = new ListObjectsV2Command({
        Bucket: config.websiteBucket
      });

      const response = await this.s3Client.send(command);
      
      if (!response.Contents) {
        console.log('📁 No existing files found in bucket');
        return;
      }

      const currentFileKeys = new Set(currentFiles.map(f => f.s3Key));
      const filesToDelete = response.Contents
        .map(obj => obj.Key)
        .filter(key => !currentFileKeys.has(key));

      if (filesToDelete.length === 0) {
        console.log('✅ No old files to delete');
        return;
      }

      console.log(`🗑️  Deleting ${filesToDelete.length} old files...`);
      
      for (const key of filesToDelete) {
        try {
          if (!config.dryRun) {
            const deleteCommand = new DeleteObjectCommand({
              Bucket: config.websiteBucket,
              Key: key
            });
            await this.s3Client.send(deleteCommand);
          }
          console.log(`🗑️  Deleted: ${key}`);
        } catch (error) {
          console.error(`❌ Failed to delete ${key}: ${error.message}`);
          this.errors.push({ file: key, error: error.message });
        }
      }
    } catch (error) {
      console.error(`❌ Failed to list existing files: ${error.message}`);
      this.errors.push({ operation: 'list-files', error: error.message });
    }
  }

  /**
   * Create CloudFront invalidation
   */
  async createInvalidation() {
    if (!config.createInvalidation || !config.cloudfrontDistributionId) {
      console.log('🔄 Skipping CloudFront invalidation');
      return;
    }

    try {
      console.log('🔄 Creating CloudFront invalidation...');
      
      const command = new CreateInvalidationCommand({
        DistributionId: config.cloudfrontDistributionId,
        InvalidationBatch: {
          Paths: {
            Quantity: 1,
            Items: ['/*']
          },
          CallerReference: `deployment-${Date.now()}`
        }
      });

      if (!config.dryRun) {
        const response = await this.s3Client.send(command);
        console.log(`✅ CloudFront invalidation created: ${response.Invalidation.Id}`);
      } else {
        console.log('✅ CloudFront invalidation would be created (dry run)');
      }
    } catch (error) {
      console.error(`❌ Failed to create CloudFront invalidation: ${error.message}`);
      this.errors.push({ operation: 'cloudfront-invalidation', error: error.message });
    }
  }

  /**
   * Format file size for display
   */
  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }

  /**
   * Main deployment function
   */
  async deploy() {
    console.log('🚀 Starting Next.js deployment to S3...');
    console.log(`📁 Build directory: ${config.buildDir}`);
    console.log(`🪣 S3 bucket: ${config.websiteBucket}`);
    console.log(`🌍 Environment: ${config.environment}`);
    
    if (config.dryRun) {
      console.log('🔍 DRY RUN MODE - No actual changes will be made');
    }

    try {
      // Validate configuration
      this.validateConfig();

      // Get all files to upload
      console.log('🔄 Scanning build directory...');
      const allFiles = this.getAllFiles(config.buildDir);
      console.log(`📄 Found ${allFiles.length} files to process`);

      // Filter files that need uploading
      console.log('🔄 Checking which files need uploading...');
      const filesToUpload = [];
      
      for (const file of allFiles) {
        if (await this.shouldUploadFile(file)) {
          filesToUpload.push(file);
        }
      }

      console.log(`📤 ${filesToUpload.length} files need uploading`);

      // Upload files
      if (filesToUpload.length > 0) {
        console.log('🔄 Uploading files...');
        
        for (const file of filesToUpload) {
          await this.uploadFile(file);
        }
      }

      // Delete old files
      await this.deleteOldFiles(allFiles);

      // Create CloudFront invalidation
      await this.createInvalidation();

      // Summary
      console.log('\n📊 Deployment Summary:');
      console.log(`✅ Files uploaded: ${this.uploadedFiles.length}`);
      console.log(`❌ Errors: ${this.errors.length}`);
      
      if (this.errors.length > 0) {
        console.log('\n❌ Errors encountered:');
        this.errors.forEach(error => {
          console.log(`   - ${error.file || error.operation}: ${error.error}`);
        });
      }

      if (this.errors.length === 0) {
        console.log('\n🎉 Deployment completed successfully!');
        
        if (config.cloudfrontDistributionId) {
          console.log(`🌐 Your site will be available at the CloudFront distribution URL`);
          console.log(`⏱️  CloudFront invalidation may take 5-15 minutes to complete`);
        }
      } else {
        console.log('\n⚠️  Deployment completed with errors');
        process.exit(1);
      }

    } catch (error) {
      console.error(`💥 Deployment failed: ${error.message}`);
      process.exit(1);
    }
  }
}

// Run deployment if this script is executed directly
if (require.main === module) {
  const deployer = new NextJSDeployer();
  deployer.deploy().catch(error => {
    console.error('💥 Unexpected error:', error);
    process.exit(1);
  });
}

module.exports = NextJSDeployer;