# Airside Labs Pre-Flight Container for AI Testing

This project packages `inspect_ai` and `inspect_evals` into a Docker container for testing AI systems and LLMs as part of CI/CD pipelines. It includes both standard evaluations (DROP, DocVQA, PIQA) and a custom evaluation called `pre_flight` that validates AI model outputs against the Airside Labs pre-flight dataset.

## Overview

Pre-Flight is a containerized solution for AI model evaluation that can be easily integrated into various CI/CD pipelines. The container provides:

- A standardized evaluation environment for AI models
- Support for both standard benchmark evaluations and custom Airside Labs evaluations
- Flexible configuration options via environment variables and CLI parameters
- Integration templates for GitHub Actions, Jenkins, and GitLab CI

## Installation Notes

Based on the official `inspect_evals` documentation, the container includes:
- `inspect_ai` installed directly from PyPI
- `inspect_evals` installed from GitHub using `git+https://github.com/UKGovernmentBEIS/inspect_evals`
- Additional packages for major LLM providers (OpenAI, Anthropic, Google)

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
docker build -t airsidelabs/pre-flight .

# Run the container with environment variables from .env file
docker run --rm \
  --env-file .env \
  -v $(pwd)/results:/app/results \
  airsidelabs/pre-flight

# Alternatively, specify variables directly
docker run --rm \
  -e API_KEY=your_api_key_here \
  -e MODEL_BASE_URL=https://api.your-ai-model.com \
  -e EVAL_TYPE=standard \
  -v $(pwd)/results:/app/results \
  airsidelabs/pre-flight
```

### Passing CLI Options to inspect eval

You can pass additional CLI options to the `inspect eval` command in two ways:

1. Using the `INSPECT_EVAL_OPTS` environment variable:

```bash
docker run --rm \
  --env-file .env \
  -e EVAL_TYPE=custom \
  -e INSPECT_EVAL_OPTS="--model openai/gpt-4 --limit 5" \
  -v $(pwd)/results:/app/results \
  airsidelabs/pre-flight
```

2. Directly as command-line arguments (will be appended to `INSPECT_EVAL_OPTS`):

```bash
docker run --rm \
  --env-file .env \
  -e EVAL_TYPE=custom \
  -v $(pwd)/results:/app/results \
  airsidelabs/pre-flight --model openai/gpt-4 --limit 5
```

Common CLI options for `inspect eval`:

| Option | Description |
|--------|-------------|
| `--model` | Specify the model to use (e.g., openai/gpt-4, anthropic/claude-3-opus) |
| `--n-samples` | Number of samples to evaluate |
| `--api-key` | API key (can also use environment variables) |
| `--max-tokens` | Maximum tokens for generation |
| `--temperature` | Temperature for sampling |
| `--timeout` | Request timeout in seconds |
| `--verbosity` | Logging verbosity (debug, info, warning, error) |

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
            ghcr.io/alexbrooker/pre_flight:latest
      
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
                      ghcr.io/alexbrooker/pre_flight:latest
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
        ghcr.io/alexbrooker/pre_flight:latest
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

## Pre-Flight Dataset

The pre-flight evaluation uses the `AirsideLabs/pre-flight-06` dataset hosted on Hugging Face. This dataset consists of multiple-choice questions drawn from standard international airport ground operations safety manuals. Each question has 4-5 possible answer choices, with one correct answer.

### Dataset Content

Topics covered include:
- Airport safety procedures
- Ground equipment operations
- Staff training requirements
- Emergency response protocols
- Fueling safety
- Aircraft towing procedures

### Dataset Organization

The dataset is organized by sections denoted by ID ranges (note there are gaps in the ID sequence to enable future additions):
- 001-205: Airport operations procedures and rules
- 206-299: Reserved for future use
- 300-399: Derived from US aviation role training material
- 400-499: ICAO annexes, rules of the air and global guidelines
- 500-599: General aviation trivia questions
- 600-699: Complex reasoning scenarios

### Example Questions

Example questions from the dataset (lightly edited for readability):

> Q: What is the effect of alcohol consumption on functions of the body?  
>    Options: 
>    A. "Alcohol has an adverse effect, especially as altitude increases." 
>    B. "Alcohol has little effect if followed by an ounce of black coffee for every ounce of alcohol."
>    C. "Small amounts of alcohol in the human system increase judgment and decision-making abilities."
>    D. "no suitable option"
>
> A: A

> Q: An airport is managing snow removal during winter operations on January 15th. Given the following information. 
> | Current time | Temperature | Snowfall                                | Ground temperature | 
> | ------------ | ----------- | --------------------------------------- | ------------------ |
> | 07:45        | -3°C        | Light, expected to continue for 2 hours | -6°C               | 
> 
> Aircraft movements and stand occupancy
> | Stand | Current/Next Departure | Next Arrival |
> | ----- | ---------------------- | --------------- |
> | A | BA23 with TOBT 07:55  | BA24 at 08:45 |
> | B | AA12 with TOBT 08:10  | AA14 at 09:00 |
> | C | Currently vacant      | ETD112 at 08:15 |
> | D | ETD17 with TOBT 08:40 | ETD234 at 09:30 | 
>
> Assuming it takes 20 minutes to clear each stand and only one stand can be cleared at a time, 
> what is the most efficient order to clear the stands to maximize the number of stands cleared 
> before they're reoccupied? Consider that stands must be cleared after an aircraft departs and 
> before the next one arrives. Answer with the stand order only for all four stands and with the 
> total duration of clearing and no preamble or other explanation, our jobs depend on this answer. 
> Example 1. A, B, C, D 1hr 20 minutes Example 2. D, A, C, B 5hr 5 minutes  
> Options:
> A. "A, B, C, D 1 hour 20 minutes"
> B. "D, A, C, B 5 hours 5 minutes"
> C. "C, A, B, D 1 hour 20 minutes"
> D. "no suitable option"
>
> A: C

### Scoring Methodology

The benchmark is scored using accuracy, which is the proportion of questions answered correctly. Each question has one correct answer from the multiple choices provided. The implementation uses the multiple_choice solver and the choice scorer.

### Evaluation Report

The following results were produced from running the full dataset (300 samples) across multiple models on March 21, 2025.

| Model | Accuracy | Correct Answers | Total Samples |
|-------|----------|----------------|---------------|
| anthropic/claude-3-7-sonnet-20250219 | 0.747 | 224 | 300 |
| openai/gpt-4o-2024-11-20 | 0.733 | 220 | 300 |
| openai/gpt-4o-mini-2024-07-18 | 0.733 | 220 | 300 |
| anthropic/claude-3-5-sonnet-20241022 | 0.713 | 214 | 300 |
| groq/llama3-70b-8192 | 0.707 | 212 | 300 |
| anthropic/claude-3-haiku-20240307 | 0.683 | 205 | 300 |
| anthropic/claude-3-5-haiku-20241022 | 0.667 | 200 | 300 |
| groq/llama3-8b-8192 | 0.660 | 198 | 300 |
| openai/gpt-4-0125-preview | 0.660 | 198 | 300 |
| openai/gpt-3.5-turbo-0125 | 0.640 | 192 | 300 |
| groq/gemma2-9b-it | 0.623 | 187 | 300 |
| groq/qwen-qwq-32b | 0.587 | 176 | 300 |
| groq/llama-3.1-8b-instant | 0.557 | 167 | 300 |

These results demonstrate the capability of modern language models to comprehend aviation safety protocols and procedures from international standards documentation. The strongest models achieve approximately 75% accuracy on the dataset.

## Custom Evaluations

The container provides a framework for adding your own custom evaluations beyond the included pre-flight evaluation. There are two methods:

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