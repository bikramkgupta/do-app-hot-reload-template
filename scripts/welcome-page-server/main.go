package main

import (
	"encoding/json"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"
)

// HealthResponse represents the JSON response for health endpoints
type HealthResponse struct {
	Status    string `json:"status"`
	Service   string `json:"service"`
	Timestamp string `json:"timestamp"`
}

// WelcomePageData holds data for the welcome page template
type WelcomePageData struct {
	RepoURL          string
	RepoFolder       string
	RepoBranch       string
	DevStartCommand  string
	WorkspacePath    string
	SyncInterval     string
	EnableDevHealth  string
	Timestamp        string
}

// welcomeHandler handles requests to the root path
func welcomeHandler(w http.ResponseWriter, r *http.Request) {
	// Only respond to root path
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}

	// Gather environment data
	data := WelcomePageData{
		RepoURL:         getEnvOrDefault("GITHUB_REPO_URL", "not set"),
		RepoFolder:      getEnvOrDefault("GITHUB_REPO_FOLDER", "not set"),
		RepoBranch:      getEnvOrDefault("GITHUB_BRANCH", "not set"),
		DevStartCommand:  getEnvOrDefault("DEV_START_COMMAND", "not set"),
		WorkspacePath:    getEnvOrDefault("WORKSPACE_PATH", "/workspaces/app"),
		SyncInterval:     getEnvOrDefault("GITHUB_SYNC_INTERVAL", "30"),
		EnableDevHealth:  getEnvOrDefault("ENABLE_DEV_HEALTH", "true"),
		Timestamp:        time.Now().UTC().Format(time.RFC3339),
	}

	// Set content type header
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)

	// Parse and execute template
	tmpl := template.Must(template.New("welcome").Parse(welcomePageHTML))
	if err := tmpl.Execute(w, data); err != nil {
		log.Printf("Error executing template: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// healthHandler handles requests to health check endpoints
// This allows health checks on port 8080 before user's app starts
func healthHandler(w http.ResponseWriter, r *http.Request) {
	response := HealthResponse{
		Status:    "ok",
		Service:   "hot-reload-container",
		Timestamp: time.Now().UTC().Format(time.RFC3339),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)

	if err := json.NewEncoder(w).Encode(response); err != nil {
		log.Printf("Error encoding health response: %v", err)
	}
}

func main() {
	// Get port from environment variable, default to 8080
	port := 8080
	if portStr := os.Getenv("WELCOME_PAGE_PORT"); portStr != "" {
		if p, err := strconv.Atoi(portStr); err == nil {
			port = p
		} else {
			log.Printf("Warning: Invalid WELCOME_PAGE_PORT value '%s', using default %d", portStr, port)
		}
	}

	// Create HTTP server
	mux := http.NewServeMux()
	mux.HandleFunc("/", welcomeHandler)
	// Health check endpoints - allows health checks on port 8080 before user's app starts
	mux.HandleFunc("/health", healthHandler)
	mux.HandleFunc("/api/health", healthHandler)

	server := &http.Server{
		Addr:         fmt.Sprintf("0.0.0.0:%d", port),
		Handler:      mux,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	// Log server start
	log.Printf("Welcome page server starting on port %d", port)
	log.Printf("Welcome page: http://0.0.0.0:%d/", port)
	log.Printf("Health endpoints: /health, /api/health")

	// Start server
	if err := server.ListenAndServe(); err != nil {
		log.Fatalf("Welcome page server error: %v", err)
	}
}

// welcomePageHTML is the HTML template for the welcome page
const welcomePageHTML = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hot Reload Dev Environment</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            background: linear-gradient(135deg, #0080ff 0%, #00d4aa 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 12px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 700px;
            width: 100%;
            padding: 40px;
        }
        h1 { color: #0080ff; margin-bottom: 10px; font-size: 2em; }
        .subtitle { color: #666; margin-bottom: 25px; font-size: 1.1em; }
        .status {
            background: #f8f9fa;
            border-left: 4px solid #0080ff;
            padding: 15px;
            margin-bottom: 25px;
            border-radius: 4px;
        }
        .status-item {
            margin: 6px 0;
            font-family: 'Monaco', 'Courier New', monospace;
            font-size: 0.85em;
        }
        .status-label { font-weight: 600; color: #555; }
        .badge {
            display: inline-block;
            padding: 2px 8px;
            border-radius: 4px;
            font-size: 0.75em;
            font-weight: 600;
            margin-left: 8px;
        }
        .badge-success { background: #d4edda; color: #155724; }
        .badge-warning { background: #fff3cd; color: #856404; }
        .badge-danger { background: #f8d7da; color: #721c24; }
        .section { margin: 25px 0; }
        .section h2 {
            color: #333;
            margin-bottom: 12px;
            font-size: 1.3em;
            border-bottom: 2px solid #0080ff;
            padding-bottom: 8px;
        }
        .step {
            background: #f8f9fa;
            padding: 15px;
            margin: 12px 0;
            border-radius: 8px;
            border-left: 4px solid #0080ff;
        }
        .code-block {
            background: #2d2d2d;
            color: #f8f8f2;
            padding: 12px;
            border-radius: 6px;
            overflow-x: auto;
            margin: 8px 0;
            font-family: 'Monaco', 'Courier New', monospace;
            font-size: 0.85em;
        }
        .env-var { color: #a6e22e; }
        .value { color: #ae81ff; }
        .comment { color: #75715e; }
        .hint { color: #888; font-style: italic; font-size: 0.85em; }
        .info {
            background: #e7f3ff;
            border-left: 4px solid #0080ff;
            padding: 12px;
            margin: 12px 0;
            border-radius: 4px;
        }
        .success {
            background: #d4edda;
            border-left: 4px solid #28a745;
            padding: 15px;
            margin: 15px 0;
            border-radius: 4px;
        }
        .footer {
            margin-top: 30px;
            padding-top: 15px;
            border-top: 1px solid #eee;
            text-align: center;
            color: #666;
            font-size: 0.85em;
        }
        a { color: #0080ff; text-decoration: none; }
        a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Hot Reload Dev Environment</h1>
        <p class="subtitle">Container deployed in ~1 minute. Now point it to your code.</p>

        <div class="status">
            <div class="status-item">
                <span class="status-label">Repository:</span>
                {{if eq .RepoURL "not set"}}<span style="color:#dc3545">not set</span><span class="badge badge-danger">Required</span>{{else}}<span style="color:#28a745">{{.RepoURL}}</span><span class="badge badge-success">OK</span>{{end}}
            </div>
            <div class="status-item">
                <span class="status-label">Start Command:</span>
                {{if eq .DevStartCommand "not set"}}<span style="color:#856404">not set</span><span class="badge badge-warning">Optional</span>{{else}}<span style="color:#28a745">{{.DevStartCommand}}</span><span class="badge badge-success">OK</span>{{end}}
            </div>
            <div class="status-item">
                <span class="status-label">Sync:</span> every {{.SyncInterval}}s
            </div>
        </div>

        {{if eq .RepoURL "not set"}}
        <div class="section">
            <h2>Recommended: GitHub Actions (AI-friendly)</h2>
            <p style="margin-bottom: 12px;">Copy the workflow and app spec into your repo, add GitHub Secrets, then run the workflow. Repo URL is auto-filled.</p>
            <div class="code-block">
gh workflow run deploy-app.yml -f action=deploy
            </div>
            <p class="hint" style="margin-top: 8px;">Full steps: https://github.com/bikramkgupta/do-app-hot-reload-template</p>
        </div>

        <div class="section">
            <h2>Setup (Console or CLI)</h2>
            <p style="margin-bottom: 12px;">Set these environment variables in App Platform (Console or app spec):</p>
            <div class="code-block">
<span class="env-var">GITHUB_REPO_URL</span> = <span class="value">https://github.com/you/your-app</span>
<span class="env-var">DEV_START_COMMAND</span> = <span class="value">bash dev_startup.sh</span>
<span class="comment"># For private repos, also set GITHUB_TOKEN (as secret)</span>
            </div>
            <p class="hint" style="margin-top: 8px;">If you used the Deploy button or Console, redeploy after setting these.</p>
        </div>
        {{else}}
        <div class="success">
            <strong>Connected!</strong> Code syncs every {{.SyncInterval}} seconds.
            {{if eq .DevStartCommand "not set"}}
            <p style="margin-top: 8px;">Add <code>dev_startup.sh</code> to your repo or set <code>DEV_START_COMMAND</code>.</p>
            {{end}}
        </div>
        {{end}}

        <div class="info">
            <strong>Where to store secrets</strong>
            <p style="margin-top: 6px;">GitHub Actions: use GitHub Secrets and reference <code>${SECRET_NAME}</code> in your app spec. Console/CLI: use App Platform env vars. Do not commit secrets to the repo.</p>
        </div>

        <div class="section">
            <h2>Example dev_startup.sh</h2>
            <div class="code-block">
<span class="comment">#!/bin/bash</span>
set -e

npm install
exec npm run dev -- --hostname 0.0.0.0 --port 8080
            </div>
            <p class="hint">Push code → syncs every {{.SyncInterval}} seconds. Your dev server handles hot reload.</p>
        </div>

        <div class="section">
            <h2>The Philosophy</h2>
            <div class="step">
                <strong>Container config (App Platform):</strong> Where is your code? How to start it?
                <div class="code-block" style="margin-top:8px">GITHUB_REPO_URL, DEV_START_COMMAND</div>
            </div>
            <div class="step">
                <strong>App secrets (Actions or Console):</strong> Store in GitHub Secrets or App Platform env vars
                <div class="code-block" style="margin-top:8px">DATABASE_URL, API_KEY, STRIPE_SECRET, etc.</div>
            </div>
            <p class="hint" style="margin-top: 12px;">Git push → syncs in {{.SyncInterval}} seconds. No redeploy needed for code changes.</p>
        </div>

        <div class="footer">
            <p>Container started: {{.Timestamp}} | Health: <code>/dev_health</code> port 9090</p>
        </div>
    </div>
</body>
</html>`
