// Next.js Configuration for AWS Infrastructure Integration
// This configuration optimizes the Next.js build for S3 static hosting and CloudFront distribution

/** @type {import('next').NextConfig} */
const nextConfig = {
  // Enable static export for S3 hosting
  output: 'export',
  
  // Disable image optimization for static export
  images: {
    unoptimized: true,
    // Configure domains for external images if needed
    domains: [
      // Add your CloudFront domain
      process.env.NEXT_PUBLIC_CLOUDFRONT_DOMAIN,
      // Add your custom domain if configured
      process.env.NEXT_PUBLIC_CUSTOM_DOMAIN,
      // Add any other image domains you need
    ].filter(Boolean),
  },
  
  // Configure trailing slash behavior
  trailingSlash: true,
  
  // Configure asset prefix for CloudFront
  assetPrefix: process.env.NODE_ENV === 'production' 
    ? `https://${process.env.NEXT_PUBLIC_CLOUDFRONT_DOMAIN || process.env.NEXT_PUBLIC_CUSTOM_DOMAIN}`
    : '',
  
  // Configure base path if deploying to a subdirectory
  // basePath: '/app',
  
  // Environment variables to expose to the browser
  env: {
    CUSTOM_KEY: process.env.CUSTOM_KEY,
  },
  
  // Configure headers for security and caching
  async headers() {
    return [
      {
        // Apply security headers to all routes
        source: '/(.*)',
        headers: [
          {
            key: 'X-Frame-Options',
            value: 'DENY',
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'Referrer-Policy',
            value: 'strict-origin-when-cross-origin',
          },
          {
            key: 'Permissions-Policy',
            value: 'camera=(), microphone=(), geolocation=()',
          },
        ],
      },
      {
        // Cache static assets aggressively
        source: '/_next/static/(.*)',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, max-age=31536000, immutable',
          },
        ],
      },
      {
        // Cache HTML files with revalidation
        source: '/(.*).html',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, max-age=0, s-maxage=86400, must-revalidate',
          },
        ],
      },
    ];
  },
  
  // Configure redirects if needed
  async redirects() {
    return [
      // Example redirect
      // {
      //   source: '/old-path',
      //   destination: '/new-path',
      //   permanent: true,
      // },
    ];
  },
  
  // Configure rewrites for API routes or SPA behavior
  async rewrites() {
    return [
      // Example: Proxy API calls to backend
      // {
      //   source: '/api/:path*',
      //   destination: `${process.env.NEXT_PUBLIC_API_BASE_URL}/api/:path*`,
      // },
    ];
  },
  
  // Webpack configuration for additional optimizations
  webpack: (config, { buildId, dev, isServer, defaultLoaders, webpack }) => {
    // Add custom webpack configurations here
    
    // Example: Add bundle analyzer in development
    if (dev && process.env.ANALYZE === 'true') {
      const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer');
      config.plugins.push(
        new BundleAnalyzerPlugin({
          analyzerMode: 'server',
          openAnalyzer: true,
        })
      );
    }
    
    // Example: Optimize for production
    if (!dev) {
      // Add production-specific optimizations
      config.optimization = {
        ...config.optimization,
        splitChunks: {
          ...config.optimization.splitChunks,
          cacheGroups: {
            ...config.optimization.splitChunks.cacheGroups,
            // Create separate chunks for AWS SDK and other large libraries
            aws: {
              test: /[\\/]node_modules[\\/](@aws-sdk|aws-amplify)[\\/]/,
              name: 'aws',
              chunks: 'all',
              priority: 10,
            },
            vendor: {
              test: /[\\/]node_modules[\\/]/,
              name: 'vendors',
              chunks: 'all',
              priority: 5,
            },
          },
        },
      };
    }
    
    return config;
  },
  
  // Configure experimental features
  experimental: {
    // Enable modern JavaScript features
    esmExternals: true,
    
    // Enable server components if using Next.js 13+
    // appDir: true,
  },
  
  // Configure compiler options
  compiler: {
    // Remove console logs in production
    removeConsole: process.env.NODE_ENV === 'production' ? {
      exclude: ['error'],
    } : false,
    
    // Enable SWC minification
    swcMinify: true,
  },
  
  // Configure TypeScript (if using TypeScript)
  typescript: {
    // Ignore TypeScript errors during build (not recommended for production)
    // ignoreBuildErrors: false,
  },
  
  // Configure ESLint (if using ESLint)
  eslint: {
    // Ignore ESLint errors during build (not recommended for production)
    // ignoreDuringBuilds: false,
  },
  
  // Configure PoweredByHeader
  poweredByHeader: false,
  
  // Configure React Strict Mode
  reactStrictMode: true,
  
  // Configure SWC (Speedy Web Compiler)
  swcMinify: true,
  
  // Configure page extensions
  pageExtensions: ['ts', 'tsx', 'js', 'jsx', 'md', 'mdx'],
  
  // Configure internationalization if needed
  // i18n: {
  //   locales: ['en', 'es', 'fr'],
  //   defaultLocale: 'en',
  // },
};

// Environment-specific configurations
if (process.env.NODE_ENV === 'development') {
  // Development-specific configurations
  nextConfig.devIndicators = {
    buildActivity: true,
    buildActivityPosition: 'bottom-right',
  };
}

if (process.env.NODE_ENV === 'production') {
  // Production-specific configurations
  nextConfig.compress = true;
  
  // Add Content Security Policy
  const ContentSecurityPolicy = `
    default-src 'self';
    script-src 'self' 'unsafe-eval' 'unsafe-inline' *.amazonaws.com *.amazoncognito.com;
    style-src 'self' 'unsafe-inline';
    img-src 'self' data: blob: *.amazonaws.com;
    font-src 'self' data:;
    connect-src 'self' *.amazonaws.com *.amazoncognito.com ${process.env.NEXT_PUBLIC_API_BASE_URL || ''};
    frame-src 'none';
    object-src 'none';
    base-uri 'self';
    form-action 'self';
    frame-ancestors 'none';
    upgrade-insecure-requests;
  `.replace(/\s{2,}/g, ' ').trim();
  
  // Add CSP header
  if (nextConfig.headers) {
    const existingHeaders = nextConfig.headers;
    nextConfig.headers = async () => {
      const headers = await existingHeaders();
      headers.push({
        source: '/(.*)',
        headers: [
          {
            key: 'Content-Security-Policy',
            value: ContentSecurityPolicy,
          },
        ],
      });
      return headers;
    };
  }
}

// Export configuration based on environment
module.exports = nextConfig;

// Alternative export for ES modules
// export default nextConfig;