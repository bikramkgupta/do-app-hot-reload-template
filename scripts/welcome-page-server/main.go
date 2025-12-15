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
        .step-number {
            display: inline-block;
            background: #0080ff;
            color: white;
            width: 24px;
            height: 24px;
            border-radius: 50%;
            text-align: center;
            line-height: 24px;
            font-weight: bold;
            font-size: 0.85em;
            margin-right: 8px;
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
        .hint { color: #888; font-style: italic; font-size: 0.85em; }
        .warning {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
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
        <p class="subtitle">Your container deployed in ~1 minute! Now connect your application.</p>

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
                <span class="status-label">Sync Interval:</span> {{.SyncInterval}}s
                <span class="hint">(code syncs automatically)</span>
            </div>
        </div>

        {{if eq .RepoURL "not set"}}
        <div class="section">
            <h2>Quick Start (2 steps)</h2>

            <div class="step">
                <span class="step-number">1</span>
                <strong>Set your repository URL</strong>
                <p style="margin-top: 8px;">Go to App Platform Console → Settings → Environment Variables:</p>
                <div class="code-block">
                    <code><span class="env-var">GITHUB_REPO_URL</span> = <span class="value">https://github.com/your-username/your-repo</span></code>
                </div>
                <p class="hint">For private repos, also set GITHUB_TOKEN (as a secret)</p>
            </div>

            <div class="step">
                <span class="step-number">2</span>
                <strong>Set your startup command</strong>
                <div class="code-block">
                    <code><span class="env-var">DEV_START_COMMAND</span> = <span class="value">bash dev_startup.sh</span></code>
                </div>
                <p style="margin-top: 8px;"><strong>Example dev_startup.sh in your repo:</strong></p>
                <div class="code-block">
                    <code>#!/bin/bash<br>npm install<br>npm run dev -- --host 0.0.0.0 --port 8080</code>
                </div>
            </div>
        </div>

        <div class="warning">
            <strong>No rebuild needed!</strong> Just set the environment variables and redeploy. Your code will be cloned from GitHub automatically.
        </div>
        {{else}}
        <div class="success">
            <strong>Repository Connected!</strong>
            <p>Your code from <code>{{.RepoURL}}</code> will sync every {{.SyncInterval}} seconds.</p>
            {{if eq .DevStartCommand "not set"}}
            <p style="margin-top: 8px;"><strong>Next:</strong> Set <code>DEV_START_COMMAND</code> or add <code>dev_startup.sh</code> to your repo.</p>
            {{else}}
            <p style="margin-top: 8px;">Your app should start automatically. Check logs if you don't see it.</p>
            {{end}}
        </div>
        {{end}}

        <div class="section">
            <h2>Example Startup Scripts</h2>

            <div class="step">
                <strong>Node.js / Next.js</strong>
                <div class="code-block"><code>npm install && npm run dev -- --host 0.0.0.0 --port 8080</code></div>
            </div>

            <div class="step">
                <strong>Python / FastAPI</strong>
                <div class="code-block"><code>pip install -r requirements.txt && uvicorn main:app --host 0.0.0.0 --port 8080 --reload</code></div>
            </div>

            <div class="step">
                <strong>Go</strong>
                <div class="code-block"><code>go mod tidy && go run .</code></div>
            </div>
        </div>

        <div class="warning">
            <strong>Your app must listen on port 8080</strong> and bind to <code>0.0.0.0</code> (not localhost).
        </div>

        <div class="footer">
            <p>Container started: {{.Timestamp}}</p>
            <p>Health endpoint: <code>/health</code> on port 8080</p>
        </div>
    </div>
</body>
</html>`
