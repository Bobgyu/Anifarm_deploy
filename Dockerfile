# Build stage
FROM python:3.12-slim as builder

# 작업 디렉토리 설정
WORKDIR /app

# 시스템 패키지 설치
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# requirements.txt 복사 및 의존성 설치
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip wheel --no-cache-dir --no-deps --wheel-dir /app/wheels -r requirements.txt

# Final stage
FROM python:3.12-slim

# 작업 디렉토리 설정
WORKDIR /app

# 시스템 패키지 설치
RUN apt-get update && apt-get install -y \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# wheels 복사 및 설치
COPY --from=builder /app/wheels /wheels
COPY --from=builder /app/requirements.txt .
RUN pip install --no-cache-dir /wheels/* && \
    pip install python-dotenv && \
    rm -rf /wheels

# 필요한 디렉토리 구조 생성
RUN mkdir -p /app/models && \
    mkdir -p /app/pricepython/models/carrot

# 모델 파일들을 복사할 디렉토리 생성
RUN mkdir -p /app/models/plant && \
    mkdir -p /app/models/strawberry && \
    mkdir -p /app/models/apple && \
    mkdir -p /app/models/tomato && \
    mkdir -p /app/models/grape && \
    mkdir -p /app/models/corn

# 애플리케이션 코드 복사
COPY . .

# 환경 변수 설정
ENV PYTHONUNBUFFERED=1 \
    TF_CPP_MIN_LOG_LEVEL=2 \
    TF_ENABLE_ONEDNN_OPTS=0 \
    CUDA_VISIBLE_DEVICES=-1 \
    MAX_WORKERS=1 \
    WORKER_TIMEOUT=1800 \
    WORKER_CONNECTIONS=1000

# 포트 설정
EXPOSE 8000

# 애플리케이션 실행
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1", "--timeout", "1800", "--limit-concurrency", "1000"]
