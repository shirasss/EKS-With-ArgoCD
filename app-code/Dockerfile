FROM python:3.11-slim

RUN useradd -u 10001 appuser

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

RUN mkdir /data && chown -R appuser:appuser /data

USER appuser

EXPOSE 8080

CMD ["python", "app.py"]
