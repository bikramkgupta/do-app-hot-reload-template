from fastapi import FastAPI, Request
from fastapi import Body
from datetime import datetime
import bcrypt
from typing import Dict

app = FastAPI(title="Python FastAPI Sample")


@app.get("/")
def read_root():
    return {"message": "Hello from FastAPI sample"}


@app.get("/health")
def health():
    return {"status": "ok", "service": "python-fastapi-sample", "timestamp": datetime.utcnow().isoformat() + "Z"}


@app.get("/info")
def info():
    return {
        "service": "python-fastapi-sample",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "note": "New info endpoint to verify sync/reload",
    }


@app.get("/version")
def version():
    return {
        "version": "1.0.0",
        "framework": "FastAPI",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "test": "code hot reload"
    }


@app.get("/echo")
@app.post("/echo")
def echo(request: Request):
    return {
        "method": request.method,
        "path": request.url.path,
        "query": str(request.url.query),
    }


@app.post("/hash")
def hash_password(body: Dict[str, str] = Body(...)):
    input_text = body.get("input", "")
    
    if not input_text:
        return {"error": "Empty input"}
    
    # Hash using bcrypt directly
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(input_text.encode('utf-8'), salt).decode('utf-8')
    return {
        "input": input_text,
        "hash": hashed,
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8080, reload=False)
