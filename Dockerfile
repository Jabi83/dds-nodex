FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates tini \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 10001 app
WORKDIR /app

COPY requirements.txt /app/
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY src/ /app/src/

# ==================== بخش اصلاح شده ====================
# پوشه‌ها را می‌سازیم و فایل از پیش ساخته شده را کپی می‌کنیم
RUN mkdir -p /app/config /app/data
COPY config/config.json /app/config/config.json
# ======================================================

RUN chown -R app:app /app

ENV PYTHONUNBUFFERED=1 \
  LOG_LEVEL=INFO \
  HEALTH_MAX_AGE=180 \
  CONFIG_FILE=/app/config/config.json \
  DATA_DIR=/app/data \
  DB_FILE=/app/data/traffic_state.db \
  ENABLE_FILE_LOG=0

HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD \
  python -c "import os,sys,time; p=os.path.join(os.getenv('DATA_DIR','/app/data'),'.heartbeat'); mx=int(os.getenv('HEALTH_MAX_AGE','180')); sys.exit(0 if (os.path.exists(p) and (time.time()-os.path.getmtime(p) < mx)) else 1)"

USER app
ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["python","-m","src.main"]
