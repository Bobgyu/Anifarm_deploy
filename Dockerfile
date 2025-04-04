# Build stage
FROM python:3.12-slim as builder

# 작업 디렉토리 설정
WORKDIR /app

# 시스템 패키지 설치 및 캐시 정리
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && apt-get autoremove -y

# requirements.txt 복사 및 의존성 설치
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip wheel --no-cache-dir --no-deps --wheel-dir /app/wheels -r requirements.txt

# Final stage
FROM python:3.12-slim

# 작업 디렉토리 설정
WORKDIR /app

# 시스템 패키지 설치 및 캐시 정리
RUN apt-get update && apt-get install -y \
    libpq5 \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && apt-get autoremove -y

# wheels 복사 및 설치
COPY --from=builder /app/wheels /wheels
COPY --from=builder /app/requirements.txt .

# 필요한 패키지만 선택적으로 설치
RUN pip install --no-cache /wheels/fastapi-*.whl \
    /wheels/uvicorn-*.whl \
    /wheels/python-dotenv-*.whl \
    /wheels/pydantic-*.whl \
    /wheels/httpx-*.whl \
    /wheels/requests-*.whl \
    /wheels/beautifulsoup4-*.whl \
    /wheels/lxml-html-clean-*.whl \
    /wheels/sqlalchemy-*.whl \
    /wheels/psycopg2_binary-*.whl \
    /wheels/python-jose-*.whl \
    /wheels/passlib-*.whl \
    /wheels/bcrypt-*.whl \
    /wheels/python-multipart-*.whl \
    /wheels/email-validator-*.whl \
    /wheels/PyJWT-*.whl \
    /wheels/numpy-*.whl \
    /wheels/pandas-*.whl \
    /wheels/jieba-*.whl \
    /wheels/langchain-openai-*.whl \
    /wheels/langchain-community-*.whl \
    /wheels/tiktoken-*.whl \
    /wheels/torch-*.whl \
    /wheels/torchvision-*.whl \
    /wheels/torchaudio-*.whl \
    /wheels/onnxruntime-*.whl \
    /wheels/tensorflow-*.whl \
    /wheels/python-dateutil-*.whl \
    /wheels/Pillow-*.whl

# 필요한 디렉토리 구조 생성
RUN mkdir -p /app/pricepython/models/carrot

# 애플리케이션 코드 복사
COPY . .

# 디버깅을 위한 파일 목록 출력
RUN ls -la /app

# 환경 변수 설정
ENV PYTHONUNBUFFERED=1

# 포트 설정
EXPOSE 8000

# 애플리케이션 실행
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "3"] 