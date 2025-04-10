# AI Testing Container for CI/CD

This project packages `inspect_ai` and `inspect_evals` into a Docker container for testing AI systems and LLMs as part of CI/CD pipelines. It includes both standard evaluations (DROP, DocVQA, PIQA) and a custom evaluation called `pre_flight`.

## Installation Notes

Based on the official `inspect_evals` README, the packages are installed as follows:
- `inspect_ai` is installed directly from PyPI
- `inspect_evals` is installed from GitHub using `git+https://github.com/UKGovernmentBEIS/inspect_evals`

## Features

- Reusable Docker container with inspect_ai and inspect_evals
- Support for standard and custom evaluations
- Flexible configuration via environment variables
- GitHub Actions integration
- Structured output for pipeline integration

## Directory Structure

```
pre_flight/
├── Guidelines/
│   ├── pre-flight container prd-doc.md
│   └── inspect_evals README.md
├── Dockerfile
├── entrypoint.sh
├── test.sh                      # Test script for validating setup
├── evals/
│   ├── standard/
│   │   └── standard-suite.yaml  # Configuration for standard evals
│   └── custom/
│       ├── __init__.py
│       └── pre_flight.py        # Custom evaluation implementation
├── examples/                    # Integration examples
│   ├── github-workflow-example.yml
│   ├── jenkins-pipeline-example.groovy
│   └── gitlab-ci-example.yml
├── test_data/                   # Test data for evaluations
│   ├── drop-samples.json
│   ├── docvqa-samples.json
│   ├── piqa-samples.json
│   ├── pre-flight-samples.json
│   └── sample-data.json
└── .env.template                # Environment variable template
```

## Configuration Options

The container supports the following configuration options through environment variables:

### Required Environment Variables

| Parameter | Environment Variable | Description |
|-----------|----------------------|-------------|
| API Key | API_KEY | Authentication for the AI model API |
| Model URL | MODEL_BASE_URL | Base URL for the model being tested |

### Optional Environment Variables

| Parameter | Environment Variable | Default | Description |
|-----------|----------------------|---------|-------------|
| Evaluation Type | EVAL_TYPE | `all` | Which evals to run (standard/custom/all) |
| Output Directory | OUTPUT_DIR | `/app/results` | Where to store results |
| Model Name | MODEL_NAME | (empty) | Specific model to use (if base URL supports multiple models) |
| Max Tokens | MAX_TOKENS | `1024` | Maximum number of tokens in the model response |
| Temperature | TEMPERATURE | `0.0` | Sampling temperature for model responses |
| Timeout | TIMEOUT_SECONDS | `30` | Request timeout in seconds |

## Local Usage

### Using Environment Variables

The project includes two environment variable files:
- `.env.template`: A template showing all available configuration options
- `.env`: Your local configuration with actual values (not committed to git)

To set up your environment:
1. Copy `.env.template` to `.env` if not done already
2. Edit `.env` to add your actual API keys and configuration

### Running the Container

To build and run the container locally:

```bash
# Build the container
docker build -t inspect-ai-eval .

# Run the container with environment variables from .env file
docker run --rm \
  --env-file .env \
  -v $(pwd)/results:/app/results \
  inspect-ai-eval

# Alternatively, specify variables directly
docker run --rm \
  -e API_KEY=your_api_key_here \
  -e MODEL_BASE_URL=https://api.your-ai-model.com \
  -e EVAL_TYPE=standard \
  -v $(pwd)/results:/app/results \
  inspect-ai-eval
```

## Integration Examples

This repository includes examples for integrating the container in various CI/CD systems.

See the files in the `examples/` directory for:

1. GitHub Actions workflow example (`github-workflow-example.yml`)
2. Jenkins pipeline example (`jenkins-pipeline-example.groovy`)
3. GitLab CI example (`gitlab-ci-example.yml`)

## CI/CD Integration

This container is designed to be used in CI/CD pipelines to evaluate AI models. Below are examples for integrating with popular CI/CD platforms. Complete example files are available in the `examples/` directory.

### GitHub Actions Integration

Create a workflow file in your repository (e.g., `.github/workflows/ai-preflight.yml`):

```yaml
name: AI Model Pre-Flight Check

on:
  pull_request:
    branches: [ main ]
    paths:
      - 'model/**'  # Adjust paths based on your project structure
  workflow_dispatch:  # Allow manual triggering
  schedule:
    - cron: '0 4 * * 1'  # Weekly on Mondays

jobs:
  pre-flight-check:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Create results directory
        run: mkdir -p ${{ github.workspace }}/eval-results
      
      - name: Run AI Pre-Flight Evaluations
        run: |
          docker run --rm \
            -e API_KEY=${{ secrets.AI_API_KEY }} \
            -e MODEL_BASE_URL=${{ secrets.MODEL_BASE_URL }} \
            -e MODEL_NAME=${{ github.event.inputs.model_version || 'latest' }} \
            -e EVAL_TYPE=all \
            -v ${{ github.workspace }}/eval-results:/app/results \
            ghcr.io/your-org/inspect-ai-eval:latest
      
      - name: Upload Evaluation Results
        uses: actions/upload-artifact@v3
        with:
          name: ai-eval-results
          path: ${{ github.workspace }}/eval-results/
```

See `examples/github-workflow-example.yml` for a more comprehensive example including PR comments with results.

### Jenkins Pipeline Integration

Create a Jenkinsfile in your repository:

```groovy
pipeline {
    agent any
    
    parameters {
        string(name: 'MODEL_VERSION', defaultValue: 'latest')
        choice(name: 'EVAL_TYPE', choices: ['all', 'standard', 'custom'])
    }
    
    environment {
        AI_API_KEY = credentials('ai-api-key')
        MODEL_BASE_URL = credentials('model-base-url')
    }
    
    stages {
        stage('Run Pre-Flight Evaluations') {
            steps {
                sh '''
                    mkdir -p ${WORKSPACE}/eval-results
                    
                    docker run --rm \
                      -e API_KEY=${AI_API_KEY} \
                      -e MODEL_BASE_URL=${MODEL_BASE_URL} \
                      -e MODEL_NAME=${params.MODEL_VERSION} \
                      -e EVAL_TYPE=${params.EVAL_TYPE} \
                      -v ${WORKSPACE}/eval-results:/app/results \
                      ghcr.io/your-org/inspect-ai-eval:latest
                '''
                
                archiveArtifacts artifacts: 'eval-results/**/*'
            }
        }
    }
}
```

See `examples/jenkins-pipeline-example.groovy` for a more complete example.

### GitLab CI Integration

Create a `.gitlab-ci.yml` file in your repository:

```yaml
stages:
  - evaluate

ai-model-evaluation:
  stage: evaluate
  image: docker:20.10.16
  services:
    - docker:20.10.16-dind
  variables:
    API_KEY: $AI_API_KEY
    MODEL_BASE_URL: $MODEL_BASE_URL
  script:
    - mkdir -p $CI_PROJECT_DIR/eval-results
    - |
      docker run --rm \
        -e API_KEY=$API_KEY \
        -e MODEL_BASE_URL=$MODEL_BASE_URL \
        -e EVAL_TYPE=all \
        -v $CI_PROJECT_DIR/eval-results:/app/results \
        ghcr.io/your-org/inspect-ai-eval:latest
  artifacts:
    paths:
      - eval-results/
```

See `examples/gitlab-ci-example.yml` for a more comprehensive example.

### Additional Integration Patterns

The container is designed to be flexible and work with any CI/CD system that supports Docker. The general pattern is:

1. **Create a directory** for results on the CI/CD runner
2. **Run the container** with appropriate environment variables
3. **Store the results** as artifacts or process them further

Results are stored in JSON format, making them easy to parse and integrate with reporting tools.

#### Required Secrets/Credentials

Set up these secrets/credentials in your CI/CD platform:

- `AI_API_KEY`: Authentication key for the AI model service
- `MODEL_BASE_URL`: Base URL for the model API endpoint

## Adding Custom Evaluations

The container provides a framework for adding your own custom evaluations. There are two methods:

### Method 1: Using Python Module (Recommended)

Create a custom evaluation by implementing a Python module:

1. Create your evaluation module in `evals/custom/your_eval.py`:
   ```python
   from inspect_evals.common.eval import Eval
   from inspect_evals.common.registry import register_eval
   
   class YourCustomEval(Eval):
       def __init__(self, **kwargs):
           super().__init__(**kwargs)
           # Custom initialization
       
       def load_data(self):
           # Load your evaluation data
           return data
       
       def run_single_eval(self, item):
           # Evaluate a single item
           return result
       
       def aggregate_results(self, results):
           # Aggregate all results
           return aggregated_results
   
   # Register the evaluation
   register_eval("your_custom_eval", YourCustomEval)
   ```

2. Add your evaluation data to `test_data/your-custom-eval-samples.json`

3. Update `evals/custom/__init__.py` to import your evaluation:
   ```python
   from .pre_flight import PreFlight
   from .your_eval import YourCustomEval
   
   __all__ = ["PreFlight", "YourCustomEval"]
   ```

4. Update the entrypoint.sh script to include your evaluation:
   ```bash
   # Run custom your_custom_eval
   echo "Running your_custom_eval evaluation..."
   inspect eval /app/evals/custom/your_custom_eval --output $OUTPUT_DIR/your-custom-eval-results.json
   ```

### Method 2: Using Existing Evaluations

Alternatively, you can use existing evaluations with your custom data:

1. Add your evaluation data to `test_data/`
2. Configure which evaluations to run in the entrypoint.sh script
3. Modify the entry points to use your custom data

See the `pre_flight.py` implementation for a complete example of a custom evaluation.