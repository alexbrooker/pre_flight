FROM python:3.10-slim
LABEL org.opencontainers.image.source="https://github.com/alexbrooker/pre_flight"
LABEL org.opencontainers.image.description="AI testing container for CI/CD pipelines"
LABEL org.opencontainers.image.vendor="Airside Labs"

# Install git and other dependencies
RUN apt-get update && apt-get install -y git && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install inspect_ai git+https://github.com/UKGovernmentBEIS/inspect_evals openai anthropic google-generativeai

# Set up directory structure
WORKDIR /app

# Copy eval configurations and test data
COPY ./evals/ /app/evals/
COPY ./test_data/ /app/test_data/

# Copy and make executable the entrypoint script
COPY ./entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
CMD []