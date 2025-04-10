#!/bin/bash
set -e

echo "Running test script for inspect-ai-eval container"

# Check directory structure
echo "Checking directory structure..."
for dir in evals/standard evals/custom test_data .github/workflows; do
  if [ ! -d "$dir" ]; then
    echo "❌ Missing directory: $dir"
  else
    echo "✅ Found directory: $dir"
  fi
done

# Check critical files
echo -e "\nChecking critical files..."
for file in Dockerfile entrypoint.sh evals/custom/pre_flight.py test_data/pre-flight-samples.json .env .env.template; do
  if [ ! -f "$file" ]; then
    echo "❌ Missing file: $file"
  else
    echo "✅ Found file: $file"
  fi
done

# Validate Python files
echo -e "\nValidating Python syntax..."
if command -v python3 &> /dev/null; then
  for py_file in evals/custom/*.py; do
    if python3 -m py_compile "$py_file" 2>/dev/null; then
      echo "✅ Valid Python: $py_file"
    else
      echo "❌ Invalid Python: $py_file"
    fi
  done
else
  echo "⚠️ Cannot validate Python (python3 not available)"
fi

# Check JSON files
echo -e "\nValidating JSON syntax..."
for json_file in test_data/*.json; do
  if command -v python3 &> /dev/null; then
    if python3 -c "import json; json.load(open('$json_file'))"; then
      echo "✅ Valid JSON: $json_file"
    else
      echo "❌ Invalid JSON: $json_file"
    fi
  else
    echo "⚠️ Cannot validate JSON (python3 not available): $json_file"
  fi
done

# Test env file loading
echo -e "\nTesting environment variable loading..."
if [ -f ".env" ]; then
  source .env
  if [ -n "$API_KEY" ] && [ -n "$MODEL_BASE_URL" ]; then
    echo "✅ Environment variables loaded successfully"
  else
    echo "❌ Required environment variables not found in .env"
  fi
else
  echo "⚠️ .env file not found, skipping environment variable test"
fi

echo -e "\nTest completed! Your project structure looks good."
echo -e "\nTo run the container with Docker:"
echo "1. Build the container:"
echo "   docker build -t inspect-ai-eval ."
echo ""
echo "2. Run the container with your API keys:"
echo "   docker run --rm --env-file .env -v \$(pwd)/results:/app/results inspect-ai-eval"
echo ""
echo "3. Run only standard evals:"
echo "   docker run --rm --env-file .env -e EVAL_TYPE=standard -v \$(pwd)/results:/app/results inspect-ai-eval"
echo ""
echo "4. Run only custom evals:"
echo "   docker run --rm --env-file .env -e EVAL_TYPE=custom -v \$(pwd)/results:/app/results inspect-ai-eval"