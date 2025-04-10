#!/bin/bash
set -e

# Configuration from environment variables
API_KEY=${API_KEY:?"API_KEY must be set"}
MODEL_BASE_URL=${MODEL_BASE_URL:?"MODEL_BASE_URL must be set"}
EVAL_TYPE=${EVAL_TYPE:-"all"}  # Options: standard, custom, all, debug
OUTPUT_DIR=${OUTPUT_DIR:-"/app/results"}

# Optional configuration
MODEL_NAME=${MODEL_NAME:-""}
MAX_TOKENS=${MAX_TOKENS:-1024}
TEMPERATURE=${TEMPERATURE:-0.0}
TIMEOUT_SECONDS=${TIMEOUT_SECONDS:-30}

# CLI options to pass to inspect eval (can be specified via INSPECT_EVAL_OPTS env var)
INSPECT_EVAL_OPTS=${INSPECT_EVAL_OPTS:-""}

# Add any arguments passed to the container to INSPECT_EVAL_OPTS
if [ $# -gt 0 ]; then
  INSPECT_EVAL_OPTS="$INSPECT_EVAL_OPTS $@"
fi

echo "Using inspect eval options: $INSPECT_EVAL_OPTS"

mkdir -p $OUTPUT_DIR

echo "Starting AI model evaluation..."

# Debug mode - just create sample output files without running actual evals
if [[ "$EVAL_TYPE" == "debug" ]]; then
  echo "Running in DEBUG mode - creating sample output files"
  
  # Create sample output files
  echo '{"status": "success", "debug": true}' > $OUTPUT_DIR/drop-results.json
  echo '{"status": "success", "debug": true}' > $OUTPUT_DIR/docvqa-results.json
  echo '{"status": "success", "debug": true}' > $OUTPUT_DIR/piqa-results.json
  echo '{"standard_evals": ["drop", "docvqa", "piqa"]}' > $OUTPUT_DIR/standard-results.json
  
  echo '{"status": "success", "debug": true}' > $OUTPUT_DIR/pre-flight-results.json
  echo '{"custom_evals": ["pre_flight"]}' > $OUTPUT_DIR/custom-results.json
  
  # Generate summary report
  echo '{"standard_tests": 3, "custom_tests": 1}' > $OUTPUT_DIR/summary.json
  
  echo "Debug output created in $OUTPUT_DIR"
  exit 0
fi

# Run standard evals from inspect-evals
if [[ "$EVAL_TYPE" == "standard" || "$EVAL_TYPE" == "all" ]]; then
  echo "Running standard evals..."
  
  # Set model identifier
  if [[ -n "$MODEL_NAME" ]]; then
    MODEL_IDENTIFIER="openai/${MODEL_NAME}"
  else
    MODEL_IDENTIFIER="openai/gpt-4"
  fi
  
  # Export required environment variables
  export INSPECT_EVAL_MODEL=$MODEL_IDENTIFIER
  export OPENAI_API_KEY=$API_KEY
  export ANTHROPIC_API_KEY=$API_KEY
  export GOOGLE_API_KEY=$API_KEY
  
  # Run standard evals
  echo "Running DROP evaluation..."
  inspect eval inspect_evals/drop $INSPECT_EVAL_OPTS > $OUTPUT_DIR/drop-results.json
  
  echo "Running DocVQA evaluation..."
  inspect eval inspect_evals/docvqa $INSPECT_EVAL_OPTS > $OUTPUT_DIR/docvqa-results.json
  
  echo "Running PIQA evaluation..."
  inspect eval inspect_evals/piqa $INSPECT_EVAL_OPTS > $OUTPUT_DIR/piqa-results.json
  
  # Combine results
  echo "{\"standard_evals\": [\"drop\", \"docvqa\", \"piqa\"]}" > $OUTPUT_DIR/standard-results.json
fi

# Run custom evals
if [[ "$EVAL_TYPE" == "custom" || "$EVAL_TYPE" == "all" ]]; then
  echo "Running custom evals..."
  
  # Set model identifier
  if [[ -n "$MODEL_NAME" ]]; then
    MODEL_IDENTIFIER="openai/${MODEL_NAME}"
  else
    MODEL_IDENTIFIER="openai/gpt-4"
  fi
  
  # Export required environment variables
  export INSPECT_EVAL_MODEL=$MODEL_IDENTIFIER
  export OPENAI_API_KEY=$API_KEY
  export ANTHROPIC_API_KEY=$API_KEY
  export GOOGLE_API_KEY=$API_KEY
  
  # Run custom pre_flight eval
  echo "Running pre_flight evaluation..."
  # Store the current directory
  CURRENT_DIR=$(pwd)
  # Change to custom evals directory
  cd /app/evals/custom
  # Run the eval and redirect output to the output directory
  inspect eval pre_flight.py $INSPECT_EVAL_OPTS > "$CURRENT_DIR/$OUTPUT_DIR/pre-flight-results.json"
  # Return to original directory
  cd "$CURRENT_DIR"
  
  # Save results
  echo "{\"custom_evals\": [\"pre_flight\"]}" > $OUTPUT_DIR/custom-results.json
fi

# Generate summary report
echo "{\"standard_tests\": $(grep -c \"test\" $OUTPUT_DIR/standard-results.json 2>/dev/null || echo 0), \"custom_tests\": $(grep -c \"test\" $OUTPUT_DIR/custom-results.json 2>/dev/null || echo 0)}" > $OUTPUT_DIR/summary.json

echo "Evaluation complete. Results saved to $OUTPUT_DIR"

# Exit with failure if any tests failed
if grep -q '"status": "failed"' $OUTPUT_DIR/*.json 2>/dev/null; then
  echo "Some tests failed!"
  exit 1
else
  echo "All tests passed!"
  exit 0
fi