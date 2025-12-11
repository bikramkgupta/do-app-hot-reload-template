package main

import (
	"encoding/json"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
	"gopkg.in/yaml.v3"
	"io"
	"log"
	"net/http"
	"os"
	"time"
)

func healthHandler(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    payload := map[string]string{
        "status":    "ok",
        "service":   "go-sample",
        "timestamp": time.Now().UTC().Format(time.RFC3339),
    }
    json.NewEncoder(w).Encode(payload)
}

func rootHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	payload := map[string]string{
		"message": "Hello from Go sample",
		"uuid":    uuid.New().String(),
	}
	json.NewEncoder(w).Encode(payload)
}

func infoHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	payload := map[string]string{
		"service":   "go-sample",
		"timestamp": time.Now().UTC().Format(time.RFC3339),
		"note":      "New info endpoint to verify sync/restart",
	}
	json.NewEncoder(w).Encode(payload)
}

func echoHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	payload := map[string]interface{}{
		"method": r.Method,
		"path":   r.URL.Path,
		"query":  r.URL.RawQuery,
	}
	json.NewEncoder(w).Encode(payload)
}

func hashHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		json.NewEncoder(w).Encode(map[string]string{"error": "Method not allowed. Use POST."})
		return
	}
	
	body, err := io.ReadAll(r.Body)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Failed to read request body"})
		return
	}
	defer r.Body.Close()
	
	input := string(body)
	if input == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Empty input"})
		return
	}
	
	hashedBytes, err := bcrypt.GenerateFromPassword([]byte(input), bcrypt.DefaultCost)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "Failed to generate hash"})
		return
	}
	
	payload := map[string]string{
		"input": input,
		"hash":  string(hashedBytes),
	}
	json.NewEncoder(w).Encode(payload)
}

func tokenHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		json.NewEncoder(w).Encode(map[string]string{"error": "Method not allowed. Use POST."})
		return
	}
	
	body, err := io.ReadAll(r.Body)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Failed to read request body"})
		return
	}
	defer r.Body.Close()
	
	var requestData map[string]string
	if err := json.Unmarshal(body, &requestData); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Invalid JSON"})
		return
	}
	
	username := requestData["username"]
	if username == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "username is required"})
		return
	}
	
	// Create JWT token
	secretKey := []byte("your-secret-key-change-in-production")
	claims := jwt.MapClaims{
		"username": username,
		"exp":      time.Now().Add(time.Hour * 24).Unix(),
		"iat":      time.Now().Unix(),
		"iss":      "go-sample-app",
	}
	
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString(secretKey)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "Failed to generate token"})
		return
	}
	
	payload := map[string]interface{}{
		"username": username,
		"token":    tokenString,
		"expires":  time.Now().Add(time.Hour * 24).Format(time.RFC3339),
	}
	json.NewEncoder(w).Encode(payload)
}

func yamlHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	
	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		json.NewEncoder(w).Encode(map[string]string{"error": "Method not allowed. Use POST."})
		return
	}
	
	body, err := io.ReadAll(r.Body)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Failed to read request body"})
		return
	}
	defer r.Body.Close()
	
	// Parse JSON input
	var jsonData interface{}
	if err := json.Unmarshal(body, &jsonData); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Invalid JSON input"})
		return
	}
	
	// Convert JSON to YAML using yaml.v3 library
	yamlBytes, err := yaml.Marshal(jsonData)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "Failed to convert to YAML"})
		return
	}
	
	payload := map[string]interface{}{
		"json": string(body),
		"yaml": string(yamlBytes),
	}
	json.NewEncoder(w).Encode(payload)
}

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/", rootHandler)
	mux.HandleFunc("/health", healthHandler)
	mux.HandleFunc("/info", infoHandler)
	mux.HandleFunc("/echo", echoHandler)
	mux.HandleFunc("/hash", hashHandler)
	mux.HandleFunc("/token", tokenHandler)
	mux.HandleFunc("/yaml", yamlHandler)

    port := os.Getenv("PORT")
    if port == "" {
        port = "8080"
    }

    log.Printf("starting server on :%s", port)
    if err := http.ListenAndServe(":"+port, mux); err != nil {
        log.Fatalf("server failed: %v", err)
    }
}
