// src/routes/api.js - API Routes
const express = require('express');
const router = express.Router();

// Example API routes
router.get('/', (req, res) => {
  res.json({
    message: 'API is working!',
    version: '1.0.0',
    endpoints: [
      'GET /api/users',
      'GET /api/status'
    ]
  });
});

// Example users endpoint
router.get('/users', (req, res) => {
  // This is a placeholder - replace with actual database queries
  const users = [
    { id: 1, name: 'John Doe', email: 'john@example.com' },
    { id: 2, name: 'Jane Smith', email: 'jane@example.com' }
  ];
  
  res.json({
    success: true,
    count: users.length,
    data: users
  });
});

// Example status endpoint
router.get('/status', (req, res) => {
  res.json({
    status: 'active',
    message: 'All systems operational',
    timestamp: new Date().toISOString()
  });
});

// Example POST endpoint
router.post('/users', (req, res) => {
  const { name, email } = req.body;
  
  if (!name || !email) {
    return res.status(400).json({
      error: 'Validation Error',
      message: 'Name and email are required'
    });
  }
  
  // This is a placeholder - replace with actual database operations
  const newUser = {
    id: Date.now(),
    name,
    email,
    createdAt: new Date().toISOString()
  };
  
  res.status(201).json({
    success: true,
    message: 'User created successfully',
    data: newUser
  });
});

// Example error handling
router.get('/error', (req, res, next) => {
  // Simulate an error
  const error = new Error('This is a test error');
  error.statusCode = 500;
  next(error);
});

module.exports = router;