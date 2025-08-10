// Registration Page Component
// Demonstrates Cognito user registration with validation

import React, { useEffect } from 'react';
import { useRouter } from 'next/router';
import Link from 'next/link';
import { useAuth } from '../../auth/auth-context';
import { RegisterForm } from '../../auth/auth-components';

const RegisterPage = () => {
  const router = useRouter();
  const { isAuthenticated, isLoading } = useAuth();

  // Redirect if already authenticated
  useEffect(() => {
    if (isAuthenticated) {
      const redirectTo = router.query.redirect || '/dashboard';
      router.push(redirectTo);
    }
  }, [isAuthenticated, router]);

  const handleRegistrationSuccess = (user) => {
    // Redirect to verification page with email
    router.push(`/auth/verify?email=${encodeURIComponent(user.username)}`);
  };

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-md w-full space-y-8">
        <div>
          <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">
            Create your account
          </h2>
          <p className="mt-2 text-center text-sm text-gray-600">
            Or{' '}
            <Link href="/auth/login" className="font-medium text-blue-600 hover:text-blue-500">
              sign in to your existing account
            </Link>
          </p>
        </div>
        
        <RegisterForm 
          onSuccess={handleRegistrationSuccess}
          className="mt-8"
        />
      </div>
    </div>
  );
};

export default RegisterPage;