// Next.js Middleware for Authentication
// Protects routes and handles authentication redirects

import { NextResponse } from 'next/server';

/**
 * Middleware function to protect routes
 * This runs on the Edge Runtime and can check authentication status
 */
export function middleware(request) {
  const { pathname } = request.nextUrl;
  
  // Define protected routes
  const protectedRoutes = [
    '/dashboard',
    '/profile',
    '/content',
    '/settings'
  ];
  
  // Define auth routes (redirect if already authenticated)
  const authRoutes = [
    '/auth/login',
    '/auth/register',
    '/auth/forgot-password'
  ];
  
  // Check if the current path is protected
  const isProtectedRoute = protectedRoutes.some(route => 
    pathname.startsWith(route)
  );
  
  // Check if the current path is an auth route
  const isAuthRoute = authRoutes.some(route => 
    pathname.startsWith(route)
  );
  
  // Get authentication token from cookies
  const authToken = request.cookies.get('auth-token')?.value;
  const isAuthenticated = !!authToken;
  
  // Redirect unauthenticated users from protected routes
  if (isProtectedRoute && !isAuthenticated) {
    const loginUrl = new URL('/auth/login', request.url);
    loginUrl.searchParams.set('redirect', pathname);
    return NextResponse.redirect(loginUrl);
  }
  
  // Redirect authenticated users from auth routes
  if (isAuthRoute && isAuthenticated) {
    const redirectUrl = request.nextUrl.searchParams.get('redirect') || '/dashboard';
    return NextResponse.redirect(new URL(redirectUrl, request.url));
  }
  
  return NextResponse.next();
}

/**
 * Configuration for middleware
 * Specify which routes should run the middleware
 */
export const config = {
  matcher: [
    /*
     * Match all request paths except for the ones starting with:
     * - api (API routes)
     * - _next/static (static files)
     * - _next/image (image optimization files)
     * - favicon.ico (favicon file)
     * - public folder files
     */
    '/((?!api|_next/static|_next/image|favicon.ico|public).*)',
  ],
};

/**
 * Helper function to validate JWT token (for server-side validation)
 * This would typically validate against Cognito's public keys
 */
export async function validateToken(token) {
  try {
    // In a real implementation, you would:
    // 1. Decode the JWT token
    // 2. Verify the signature using Cognito's public keys
    // 3. Check token expiration
    // 4. Validate the issuer and audience
    
    // For this example, we'll do a basic check
    if (!token || token.split('.').length !== 3) {
      return { valid: false, error: 'Invalid token format' };
    }
    
    // Decode the payload (without verification for this example)
    const payload = JSON.parse(
      Buffer.from(token.split('.')[1], 'base64').toString()
    );
    
    // Check expiration
    const now = Math.floor(Date.now() / 1000);
    if (payload.exp && payload.exp < now) {
      return { valid: false, error: 'Token expired' };
    }
    
    return { 
      valid: true, 
      payload,
      user: {
        id: payload.sub,
        email: payload.email,
        username: payload['cognito:username'],
        groups: payload['cognito:groups'] || []
      }
    };
  } catch (error) {
    return { valid: false, error: error.message };
  }
}

/**
 * Server-side authentication check for API routes
 * Use this in API routes to verify authentication
 */
export async function requireAuth(request) {
  const authHeader = request.headers.get('authorization');
  const token = authHeader?.replace('Bearer ', '');
  
  if (!token) {
    return { authenticated: false, error: 'No token provided' };
  }
  
  const validation = await validateToken(token);
  
  if (!validation.valid) {
    return { authenticated: false, error: validation.error };
  }
  
  return { 
    authenticated: true, 
    user: validation.user,
    payload: validation.payload
  };
}

/**
 * Role-based access control helper
 * Check if user has required roles
 */
export function hasRequiredRole(userGroups, requiredRoles) {
  if (!requiredRoles || requiredRoles.length === 0) {
    return true;
  }
  
  if (!userGroups || userGroups.length === 0) {
    return false;
  }
  
  return requiredRoles.some(role => userGroups.includes(role));
}

/**
 * Create a protected API route wrapper
 * Use this to wrap API routes that require authentication
 */
export function withAuth(handler, options = {}) {
  return async (request) => {
    const { requiredRoles = [] } = options;
    
    // Check authentication
    const authResult = await requireAuth(request);
    
    if (!authResult.authenticated) {
      return new Response(
        JSON.stringify({ error: authResult.error }),
        { 
          status: 401,
          headers: { 'Content-Type': 'application/json' }
        }
      );
    }
    
    // Check roles if required
    if (requiredRoles.length > 0) {
      const hasRole = hasRequiredRole(authResult.user.groups, requiredRoles);
      
      if (!hasRole) {
        return new Response(
          JSON.stringify({ error: 'Insufficient permissions' }),
          { 
            status: 403,
            headers: { 'Content-Type': 'application/json' }
          }
        );
      }
    }
    
    // Add user to request context
    request.user = authResult.user;
    request.authPayload = authResult.payload;
    
    return handler(request);
  };
}

/**
 * Example usage in API route:
 * 
 * // pages/api/protected-endpoint.js
 * import { withAuth } from '../../auth/auth-middleware';
 * 
 * async function handler(request) {
 *   // request.user is available here
 *   return new Response(JSON.stringify({ 
 *     message: 'Protected data',
 *     user: request.user 
 *   }));
 * }
 * 
 * export default withAuth(handler, { requiredRoles: ['admin'] });
 */