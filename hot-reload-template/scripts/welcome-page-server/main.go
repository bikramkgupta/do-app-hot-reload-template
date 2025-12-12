package main

import (
	"fmt"
	"html/template"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"
)

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
    <title>DigitalOcean App Platform Dev Template</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
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
            max-width: 800px;
            width: 100%;
            padding: 40px;
        }
        h1 {
            color: #667eea;
            margin-bottom: 10px;
            font-size: 2.5em;
        }
        .subtitle {
            color: #666;
            margin-bottom: 30px;
            font-size: 1.1em;
        }
        .status {
            background: #f8f9fa;
            border-left: 4px solid #667eea;
            padding: 15px;
            margin-bottom: 30px;
            border-radius: 4px;
        }
        .status-item {
            margin: 8px 0;
            font-family: 'Monaco', 'Courier New', monospace;
            font-size: 0.9em;
        }
        .status-label {
            font-weight: 600;
            color: #555;
        }
        .status-value {
            color: {{if eq .RepoURL "not set"}}#dc3545{{else}}#28a745{{end}};
        }
        .section {
            margin: 30px 0;
        }
        .section h2 {
            color: #333;
            margin-bottom: 15px;
            font-size: 1.5em;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }
        .step {
            background: #f8f9fa;
            padding: 15px;
            margin: 15px 0;
            border-radius: 8px;
            border-left: 4px solid #667eea;
        }
        .step-number {
            display: inline-block;
            background: #667eea;
            color: white;
            width: 28px;
            height: 28px;
            border-radius: 50%;
            text-align: center;
            line-height: 28px;
            font-weight: bold;
            margin-right: 10px;
        }
        .code-block {
            background: #2d2d2d;
            color: #f8f8f2;
            padding: 15px;
            border-radius: 6px;
            overflow-x: auto;
            margin: 10px 0;
            font-family: 'Monaco', 'Courier New', monospace;
            font-size: 0.9em;
        }
        .code-block code {
            color: #f8f8f2;
        }
        .env-var {
            color: #a6e22e;
        }
        .value {
            color: #ae81ff;
        }
        .warning {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            margin: 15px 0;
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
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #eee;
            text-align: center;
            color: #666;
            font-size: 0.9em;
        }
        a {
            color: #667eea;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
        .badge {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 0.8em;
            font-weight: 600;
            margin-left: 8px;
        }
        .badge-success {
            background: #d4edda;
            color: #155724;
        }
        .badge-warning {
            background: #fff3cd;
            color: #856404;
        }
        .badge-danger {
            background: #f8d7da;
            color: #721c24;
        }
        .hint-text {
            color: #888;
            font-style: italic;
            font-size: 0.85em;
            margin-left: 8px;
        }
        .ai-section {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            margin: 30px 0;
            border-radius: 8px;
            border-left: 4px solid #fff;
        }
        .ai-section h2 {
            color: white;
            border-bottom: 2px solid rgba(255,255,255,0.3);
            margin-bottom: 15px;
        }
        .ai-section p {
            margin: 10px 0;
        }
        .ai-section a {
            color: #fff;
            text-decoration: underline;
            font-weight: 600;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 DigitalOcean App Platform Dev Template</h1>
        <p class="subtitle">Your development container is running! Connect your application to get started.</p>

        <div class="status">
            <div class="status-item">
                <span class="status-label">Repository URL:</span>
                <span class="status-value">{{.RepoURL}}</span>
                {{if eq .RepoURL "not set"}}<span class="badge badge-danger">Required</span>{{else}}<span class="badge badge-success">Configured</span>{{end}}
            </div>
            <div class="status-item">
                <span class="status-label">Repository Folder:</span>
                <span class="status-value">{{.RepoFolder}}</span>
                {{if eq .RepoFolder "not set"}}<span class="hint-text">(leave blank for root folder)</span>{{end}}
            </div>
            <div class="status-item">
                <span class="status-label">Branch:</span>
                <span class="status-value">{{.RepoBranch}}</span>
                {{if eq .RepoBranch "not set"}}<span class="hint-text">(leave blank for main branch)</span>{{end}}
            </div>
            <div class="status-item">
                <span class="status-label">Dev Start Command:</span>
                <span class="status-value">{{.DevStartCommand}}</span>
                {{if eq .DevStartCommand "not set"}}<span class="badge badge-warning">Not Set</span>{{else}}<span class="badge badge-success">Configured</span>{{end}}
            </div>
            <div class="status-item">
                <span class="status-label">Workspace Path:</span>
                <span class="status-value">{{.WorkspacePath}}</span>
            </div>
            <div class="status-item">
                <span class="status-label">Sync Interval:</span>
                <span class="status-value">{{.SyncInterval}}s</span>
            </div>
            <div class="status-item">
                <span class="status-label">Dev Health Server:</span>
                <span class="status-value">{{.EnableDevHealth}}</span>
            </div>
        </div>

        {{if eq .RepoURL "not set"}}
        <div class="section">
            <h2>📋 Quick Start Guide</h2>
            
            <div class="step">
                <span class="step-number">1</span>
                <strong>Bulk Configuration (Recommended)</strong>
                <p>The fastest way to configure your app is using the App Platform bulk editor with pre-configured .env.example files from app-examples folder:</p>
                <ul style="margin: 10px 0 10px 20px;">
                    <li><strong>Next.js apps:</strong> <a href="https://github.com/bikram20/do-app-platform-ai-dev-workflow/blob/main/hot-reload-template/app-examples/nextjs-sample-app/.env.example" target="_blank">nextjs .env.example</a></li>
                    <li><strong>Python FastAPI apps:</strong> <a href="https://github.com/bikram20/do-app-platform-ai-dev-workflow/blob/main/hot-reload-template/app-examples/python-fastapi-sample/.env.example" target="_blank">python-fastapi .env.example</a></li>
                    <li><strong>Go apps:</strong> <a href="https://github.com/bikram20/do-app-platform-ai-dev-workflow/blob/main/hot-reload-template/app-examples/go-sample-app/.env.example" target="_blank">go .env.example</a></li>
                </ul>
                <p><strong>How to use:</strong></p>
                <ol style="margin: 10px 0 10px 20px;">
                    <li>Open the .env.example file for your framework</li>
                    <li>Copy all contents</li>
                    <li>In App Platform UI → Settings → click "Bulk Editor"</li>
                    <li>Paste the contents and adjust GITHUB_REPO_URL to your repository</li>
                </ol>
                <p><strong>Advantage:</strong> Copy-paste all settings at once instead of adding them one by one.</p>
                <p style="margin-top: 15px;"><strong>Or set variables individually:</strong></p>
                <div class="code-block">
                    <code><span class="env-var">GITHUB_REPO_URL</span> = <span class="value">https://github.com/your-username/your-repo.git</span><br>
<span class="env-var">GITHUB_REPO_FOLDER</span> = <span class="value">subfolder/path</span> <span class="hint-text">(leave blank for root folder)</span><br>
<span class="env-var">GITHUB_BRANCH</span> = <span class="value">main</span> <span class="hint-text">(leave blank for main branch)</span></code>
                </div>
            </div>

            <div class="step">
                <span class="step-number">2</span>
                <strong>Configure Your Startup Command</strong>
                <p><strong>Both are needed:</strong> Set DEV_START_COMMAND and create a dev_startup.sh in your repository</p>
                <div class="code-block">
                    <code><span class="env-var">DEV_START_COMMAND</span> = <span class="value">bash dev_startup.sh</span></code>
                </div>
                <p style="margin-top: 15px;"><strong>Why dev_startup.sh is better than a 1-liner DEV_START_COMMAND:</strong></p>
                <ul style="margin: 10px 0 10px 20px;">
                    <li>You control and version it in your repo (not locked in App Platform settings)</li>
                    <li>Easier to update without redeploying the container</li>
                    <li>Can include complex logic, error handling, and dependency management</li>
                </ul>
                <p style="margin-top: 10px;"><strong>Example dev_startup.sh for Next.js:</strong></p>
                <div class="code-block">
                    <code>#!/bin/bash<br>cd /workspaces/app<br>npm install<br>npm run dev -- --hostname 0.0.0.0 --port 8080</code>
                </div>
                <p style="margin-top: 10px;">See ready-made templates in <a href="https://github.com/bikram20/do-app-platform-ai-dev-workflow/tree/main/hot-reload-template/examples" target="_blank">hot-reload-template/examples</a>, and ask your AI assistant to tailor a dev_startup.sh for your specific codebase.</p>
            </div>

            <div class="step">
                <span class="step-number">3</span>
                <strong>Configure Build Arguments (Build-time)</strong>
                <p>Go to App Platform UI → Settings → Build Arguments and enable only what you need:</p>
                <p style="margin-top: 10px;"><em>Note: These are BUILD_TIME scope arguments that determine which language runtimes are installed during container build.</em></p>
                <div class="code-block">
                    <code><span class="env-var">INSTALL_NODE</span> = <span class="value">true</span>  # For Node.js/Next.js apps<br>
<span class="env-var">INSTALL_PYTHON</span> = <span class="value">true</span>  # For Python/FastAPI apps<br>
<span class="env-var">INSTALL_GOLANG</span> = <span class="value">true</span>  # For Go apps<br>
<span class="env-var">INSTALL_RUST</span> = <span class="value">false</span>  # For Rust apps</code>
                </div>
            </div>

            <div class="step">
                <span class="step-number">4</span>
                <strong>Redeploy Your App</strong>
                <p>After setting environment variables, trigger a new deployment to apply changes.</p>
            </div>
        </div>

        <div class="ai-section">
            <h2>🤖 Automate Setup with AI Assistants</h2>
            <p><strong>Skip manual configuration!</strong> AI assistants can automate the entire deployment process:</p>
            <ul style="margin: 15px 0 15px 20px;">
                <li>Automatically create and configure your app on App Platform</li>
                <li>Set all required environment variables and build arguments</li>
                <li>Generate dev_startup.sh scripts tailored to your application</li>
                <li>Monitor deployment and troubleshoot issues</li>
                <li>Execute commands in your running container for debugging</li>
            </ul>
            <p style="margin-top: 15px;"><strong>Supported AI assistants:</strong> Claude Code, GitHub Copilot, Cursor, Codex, Antigravity, or any agent that can execute commands</p>
            <p><strong>Get started:</strong> See the <a href="https://github.com/bikram20/do-app-platform-ai-dev-workflow/blob/main/hot-reload-template/agent.md" target="_blank">agent.md playbook</a> for detailed automation instructions.</p>
        </div>
        {{else}}
        <div class="success">
            <strong>✓ Repository Configured!</strong>
            <p>Your repository is set to: <code>{{.RepoURL}}</code></p>
            {{if eq .DevStartCommand "not set"}}
            <p style="margin-top: 10px;"><strong>Next:</strong> Set <code>DEV_START_COMMAND</code> or add a <code>dev_startup.sh</code> script to your repository.</p>
            {{else}}
            <p style="margin-top: 10px;"><strong>Next:</strong> Your app should start automatically. Check the logs if you don't see your application.</p>
            {{end}}
        </div>
        {{end}}

        <div class="section">
            <h2>📚 Example dev_startup.sh Scripts</h2>
            
            <div class="step">
                <strong>Next.js / React</strong>
                <div class="code-block">
                    <code>#!/bin/bash<br>cd /workspaces/app<br>npm install<br>npm run dev -- --hostname 0.0.0.0 --port 8080</code>
                </div>
                <p style="margin-top: 8px;">Starting point only—use your AI assistant to generate a dev_startup.sh tailored to your project, or copy from the <a href="https://github.com/bikram20/do-app-platform-ai-dev-workflow/tree/main/hot-reload-template/examples" target="_blank">examples directory</a>.</p>
            </div>

            <div class="step">
                <strong>Python FastAPI</strong>
                <div class="code-block">
                    <code>#!/bin/bash<br>cd /workspaces/app<br>uv sync --no-dev<br>uv run uvicorn main:app --host 0.0.0.0 --port 8080 --reload</code>
                </div>
                <p style="margin-top: 8px;">Adapt with your AI assistant or reuse the <a href="https://github.com/bikram20/do-app-platform-ai-dev-workflow/tree/main/hot-reload-template/examples" target="_blank">examples/dev_startup.sh.python</a> template.</p>
            </div>

            <div class="step">
                <strong>Go</strong>
                <div class="code-block">
                    <code>#!/bin/bash<br>cd /workspaces/app<br>go mod tidy<br>go run main.go</code>
                </div>
                <p style="margin-top: 8px;">Have your AI assistant extend this for your modules, or copy from <a href="https://github.com/bikram20/do-app-platform-ai-dev-workflow/tree/main/hot-reload-template/examples" target="_blank">examples/dev_startup.sh.golang</a> and adjust.</p>
            </div>
        </div>

        <div class="section">
            <h2>🔧 Important Notes</h2>
            
            <div class="warning">
                <strong>⚠️ Your app must listen on port 8080</strong>
                <p>Make sure your development server binds to <code>0.0.0.0:8080</code> (not <code>localhost</code> or <code>127.0.0.1</code>).</p>
            </div>

            <div class="warning">
                <strong>🔄 Hot Reload is Automatic</strong>
                <p>Your repository syncs every {{.SyncInterval}} seconds (configurable via GITHUB_SYNC_INTERVAL environment variable, default is 15s). Use a dev server with hot reload (like <code>npm run dev</code>, <code>uvicorn --reload</code>, or <code>air</code>) to see changes without restarting.</p>
            </div>

            <div class="warning">
                <strong>🏥 Health Check</strong>
                <p>The built-in health server runs on port 9090 at <code>/dev_health</code>. Once your app has its own health endpoint, set <code>ENABLE_DEV_HEALTH=false</code> and point health checks to your app.</p>
            </div>
        </div>

        <div class="footer">
            <p>Container started at: {{.Timestamp}}</p>
            <p>For more information, see the <a href="https://github.com/bikram20/do-app-platform-ai-dev-workflow" target="_blank">template repository</a></p>
        </div>
    </div>
</body>
</html>`
