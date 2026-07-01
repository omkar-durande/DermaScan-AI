FROM python:3.11-slim

# Prevents Python from buffering stdout/stderr
ENV PYTHONUNBUFFERED=1

# Create a non-root user for Hugging Face Spaces compatibility and write permissions
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH

WORKDIR $HOME/app

# Install Python deps (CPU-only torch to keep image small)
COPY --chown=user requirements.txt .
RUN pip install --no-cache-dir \
    --extra-index-url https://download.pytorch.org/whl/cpu \
    -r requirements.txt

# Copy application code and model
COPY --chown=user main.py model.py ./
COPY --chown=user skin_model.pth ./

# Expose the API port (Hugging Face Spaces expects 7860)
EXPOSE 7860

# Start the server
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7860"]
