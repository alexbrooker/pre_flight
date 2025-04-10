FROM python:3.10-slim

# Install dependencies
RUN pip install inspect_ai git+https://github.com/UKGovernmentBEIS/inspect_evals

# Set up directory structure
WORKDIR /app

# Copy eval configurations and test data
COPY ./evals/ /app/evals/
COPY ./test_data/ /app/test_data/

# Copy and make executable the entrypoint script
COPY ./entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]