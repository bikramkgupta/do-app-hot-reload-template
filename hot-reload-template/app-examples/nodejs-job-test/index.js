const express = require('express');
const app = express();
const port = process.env.PORT || 8080;

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    message: 'Node.js app with PRE/POST deploy jobs'
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
      <head>
        <title>Node.js Hot Reload Job Test</title>
        <style>
          body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
          h1 { color: #333; }
          .status { background: #e7f3e7; border-left: 4px solid #4caf50; padding: 15px; margin: 20px 0; }
          code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }
        </style>
      </head>
      <body>
        <h1>Node.js Hot Reload Job Test</h1>
        <div class="status">
          <strong>Status:</strong> Application is running successfully!
        </div>
        <p>This is a test application for validating PRE_DEPLOY and POST_DEPLOY job functionality with the hot-reload template.</p>
        <h2>Features:</h2>
        <ul>
          <li>Express server on port ${port}</li>
          <li>Health check endpoint at <code>/health</code></li>
          <li>Hot-reload via nodemon</li>
          <li>PRE_DEPLOY job: Database migration simulation</li>
          <li>POST_DEPLOY job: Data seeding simulation</li>
        </ul>
        <h2>Endpoints:</h2>
        <ul>
          <li><a href="/">/</a> - This page</li>
          <li><a href="/health">/health</a> - Health check (JSON)</li>
        </ul>
        <p><small>Server started at: ${new Date().toISOString()}</small></p>
      </body>
    </html>
  `);
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Server is running on http://0.0.0.0:${port}`);
  console.log(`Health check available at http://0.0.0.0:${port}/health`);
});
