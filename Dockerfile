FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates tini dos2unix \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 10001 app
WORKDIR /app

COPY requirements.txt /app/
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY src/ /app/src/

RUN mkdir -p /app/config /app/data
COPY config/config.json /app/config/config.json

# ==================== بخش اصلاح شده ====================
# اسکریپت ورودی جدید را کپی می‌کنیم
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# 1. فرمت فایل را از ویندوز (CRLF) به یونیکس (LF) تبدیل می‌کنیم تا خطای no such file ندهد
# 2. اسکریپت را قابل اجرا می‌کنیم
RUN dos2unix /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/entrypoint.sh
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

# ==================== بخش اصلاح شده ====================
# نقطه ورود را با مسیر کامل و مطلق مشخص می‌کنیم
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["python","-m","src.main"]
