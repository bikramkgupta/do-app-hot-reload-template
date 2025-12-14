# Blank Node.js Template

A minimal Node.js/Express template for DigitalOcean App Platform with hot-reload support.

## Features

- **Express.js** - Minimal web server
- **Hot-reload** - Automatic restart on code changes via nodemon
- **Hash-based dependency detection** - Reinstalls dependencies only when `package.json` changes

## Getting Started

1. Copy this template to your project
2. Update `appspec.yaml` with your GitHub repo details
3. Add your routes and dependencies
4. Deploy to App Platform

## Local Development

```bash
npm install
npm run dev
```

## Endpoints

- `GET /` - Welcome message
- `GET /health` - Health check endpoint

## Adding Dependencies

When you add a new dependency to `package.json` and push to GitHub, the hot-reload system will:

1. Detect the `package.json` change via hash comparison
2. Automatically run `npm install`
3. Restart the application

This happens within ~30 seconds without triggering a full rebuild.
