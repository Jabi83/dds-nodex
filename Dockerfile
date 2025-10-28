FROM python:3.12-slim

# نصب ابزارهای ضروری
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates tini \
  && rm -rf /var/lib/apt/lists/*

# ساخت کاربر غیر روت برای امنیت بیشتر
RUN useradd -m -u 10001 app
WORKDIR /app

# نصب وابستگی‌های پایتون
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r /app/requirements.txt

# کپی کردن سورس کد برنامه
COPY src/ /app/src/

# ==================== بخش اصلاح شده ====================

# 1. ابتدا پوشه‌های config و data را می‌سازیم
RUN mkdir -p /app/config /app/data

# 2. آرگومان حاوی محتوای config.json را از secret گیت‌هاب دریافت می‌کنیم
ARG CONFIG_JSON_CONTENT

# 3. حالا که پوشه وجود دارد، فایل config.json را با محتوای دریافتی ایجاد می‌کنیم
RUN echo "${CONFIG_JSON_CONTENT}" > /app/config/config.json

# 4. مالکیت تمام فایل‌ها و پوشه‌ها را به کاربر app می‌دهیم
RUN chown -R app:app /app

# ======================================================

# تنظیم متغیرهای محیطی
ENV PYTHONUNBUFFERED=1 \
  LOG_LEVEL=INFO \
  HEALTH_MAX_AGE=180 \
  CONFIG_FILE=/app/config/config.json \
  DATA_DIR=/app/data \
  DB_FILE=/app/data/traffic_state.db \
  ENABLE_FILE_LOG=0

# تعریف Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD \
  python -c "import os,sys,time; p=os.path.join(os.getenv('DATA_DIR','/app/data'),'.heartbeat'); mx=int(os.getenv('HEALTH_MAX_AGE','180')); sys.exit(0 if (os.path.exists(p) and (time.time()-os.path.getmtime(p) < mx)) else 1)"

# اجرای برنامه با کاربر غیر روت
USER app
ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["python","-m","src.main"]
