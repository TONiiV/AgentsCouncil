#!/bin/bash

# Configuration
OLLAMA_HOST="localhost"
OLLAMA_PORT="11434"
OLLAMA_URL="http://$OLLAMA_HOST:$OLLAMA_PORT"

# Function to check if Ollama is running
check_ollama() {
    if curl -s "$OLLAMA_URL/api/version" > /dev/null; then
        return 0
    else
        return 1
    fi
}

echo "🤖 Checking Ollama status..."

if check_ollama; then
    echo "✅ Ollama is already running at $OLLAMA_URL"
else
    echo "⚠️  Ollama is not running."
    
    # Check if ollama is installed
    if command -v ollama &> /dev/null; then
        echo "🚀 Starting Ollama..."
        # Start in background
        ollama serve &> /dev/null &
        
        # Wait for it to start
        echo "⏳ Waiting for Ollama to initialize..."
        COUNT=0
        while ! check_ollama; do
            sleep 1
            ((COUNT++))
            if [ $COUNT -ge 30 ]; then
                echo "❌ Failed to start Ollama (timeout)."
                exit 1
            fi
        done
        echo "✅ Ollama started successfully!"
    else
        echo "❌ Ollama is not installed. Please install it from https://ollama.com/"
        exit 1
    fi
fi

# List available models
echo "📋 Available Ollama models:"
if command -v ollama &> /dev/null; then
    ollama list
else
    # Fallback to API if CLI not available (unlikely if we started it)
    curl -s "$OLLAMA_URL/api/tags" | grep -o '"name":"[^"]*"' | cut -d'"' -f4
fi
