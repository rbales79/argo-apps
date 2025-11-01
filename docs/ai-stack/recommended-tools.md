# AI Stack - Recommended Tools

This document provides a comprehensive list of recommended AI tools for inference, learning, and AI application development that complement the existing stack (LiteLLM, Ollama, Open-WebUI).

## Inference & Model Serving

### vLLM

High-performance inference server with PagedAttention, excellent for production LLM serving

- Superior performance for concurrent requests
- OpenAI-compatible API
- Continuous batching

### LocalAI

OpenAI-compatible API for local models (alternative/complement to LiteLLM)

- Supports multiple model formats (GGUF, GGML, etc.)
- Audio transcription, image generation
- Text-to-speech capabilities

### TGI (Text Generation Inference)

Hugging Face's production inference server

- Optimized for Hugging Face models
- Tensor parallelism for large models
- Production-ready with monitoring

### Triton Inference Server

NVIDIA's multi-framework inference server

- Supports TensorFlow, PyTorch, ONNX, TensorRT
- Dynamic batching and model ensembles
- Best for multi-model deployments

## Learning & Training

### JupyterHub

Multi-user Jupyter notebook environment

- Essential for ML experimentation
- GPU support
- Collaborative workspace

### MLflow

ML lifecycle management platform

- Experiment tracking
- Model registry
- Model deployment

### Ray (KubeRay)

Distributed computing framework

- Distributed training (Ray Train)
- Hyperparameter tuning (Ray Tune)
- Reinforcement learning (Ray RLlib)

### Kubeflow

Complete ML platform on Kubernetes

- Pipelines for ML workflows
- Training operators (PyTorch, TensorFlow)
- Model serving (KServe)
- More heavyweight but comprehensive

## Vector Databases & RAG

### Qdrant

High-performance vector database

- Essential for RAG applications
- Excellent performance
- Easy to deploy

### Weaviate

Vector database with built-in vectorization

- GraphQL API
- Hybrid search capabilities
- Multiple vectorizer options

### Milvus

Scalable vector database

- High throughput
- Multiple index types
- Production-ready

### Chroma

Lightweight embedding database

- Simple to use
- Good for development/testing

## AI Development & Experimentation

### Langfuse

LLM observability and analytics

- Trace LLM calls
- Cost tracking
- Prompt management
- Integrates with LiteLLM

### Flowise

Low-code LLM orchestration

- Visual workflow builder for AI apps
- RAG pipelines
- Agent building

### n8n

Workflow automation (you might already have from productivity)

- AI workflow automation
- Connect LLMs to various services

### Dify

LLMOps platform

- Build AI apps without code
- Prompt engineering
- Dataset management

## Model Management & Optimization

### HuggingFace Text Embeddings Inference (TEI)

Optimized embedding server

- Fast embedding generation
- Essential for RAG pipelines
- Low resource usage

### ONNX Runtime Server

Cross-platform inference

- Model optimization
- Hardware acceleration
- Multi-framework support

## AI-Specific Monitoring & Management

### Prometheus + Grafana dashboards

(you may have these)

- AI-specific metrics dashboards
- Model performance tracking
- GPU utilization monitoring

### OpenTelemetry Collector

Distributed tracing for AI pipelines

- Track end-to-end latency
- Debug complex AI workflows

## Top 5 Recommendations to Start With

Based on your existing setup and typical use cases:

1. **vLLM** - Production-grade inference (complements Ollama for performance)
2. **Qdrant** - Vector database for RAG applications
3. **JupyterHub** - For learning/experimentation
4. **Langfuse** - LLM observability (integrates with your LiteLLM)
5. **HuggingFace TEI** - Fast embeddings for RAG

## Current Stack

For reference, the current AI stack includes:

- **LiteLLM** - Unified API to manage and deploy LLMs
- **Ollama** - Run large language models locally
- **Open-WebUI** - User-friendly WebUI for LLMs
