// tests/unit/app.test.js
// Basic tests for the application

const request = require('supertest');
const app = require('../../src/app');

describe('API Endpoints', () => {
  // Test root endpoint
  test('GET / should return welcome message', async () => {
    const response = await request(app).get('/');
    expect(response.statusCode).toBe(200);
    expect(response.body).toHaveProperty('message');
    expect(response.body.status).toBe('running');
  });

  // Test health check
  test('GET /health should return OK status', async () => {
    const response = await request(app).get('/health');
    expect(response.statusCode).toBe(200);
    expect(response.body.status).toBe('OK');
    expect(response.body).toHaveProperty('uptime');
  });

  // Test health detailed
  test('GET /health/detailed should return detailed health info', async () => {
    const response = await request(app).get('/health/detailed');
    expect(response.statusCode).toBe(200);
    expect(response.body).toHaveProperty('memory');
    expect(response.body).toHaveProperty('cpu');
    expect(response.body).toHaveProperty('version');
  });

  // Test API endpoint
  test('GET /api should return API info', async () => {
    const response = await request(app).get('/api');
    expect(response.statusCode).toBe(200);
    expect(response.body.message).toBe('API is working!');
  });

  // Test users endpoint
  test('GET /api/users should return users array', async () => {
    const response = await request(app).get('/api/users');
    expect(response.statusCode).toBe(200);
    expect(response.body.success).toBe(true);
    expect(Array.isArray(response.body.data)).toBe(true);
    expect(response.body.count).toBe(2);
  });

  // Test 404 handler
  test('GET /nonexistent should return 404', async () => {
    const response = await request(app).get('/nonexistent');
    expect(response.statusCode).toBe(404);
    expect(response.body).toHaveProperty('error');
  });
});

describe('Health Check Endpoints', () => {
  test('GET /health/ready should return ready status', async () => {
    const response = await request(app).get('/health/ready');
    expect(response.statusCode).toBe(200);
    expect(response.body.ready).toBe(true);
  });

  test('GET /health/live should return alive status', async () => {
    const response = await request(app).get('/health/live');
    expect(response.statusCode).toBe(200);
    expect(response.body.alive).toBe(true);
  });
});