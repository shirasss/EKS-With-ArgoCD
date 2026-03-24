from flask import Flask, jsonify, Response, request
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST
import os
import logging

app = Flask(__name__)

# Simple logging to stdout
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Persistence
DATA_DIR = "/data"
COUNTER_FILE = f"{DATA_DIR}/counter.txt"
VERSION = os.getenv("VERSION", "v1")

logger.info(f"App started with VERSION={VERSION}")

def read_counter():
    try:
        with open(COUNTER_FILE, "r") as f:
            return int(f.read())
    except Exception:
        return 0

def write_counter(value):
    with open(COUNTER_FILE, "w") as f:
        f.write(str(value))

# Prometheus metrics
POST_COUNTER = Counter('counter_post_requests_total', 'Total POST requests to increment the counter')
GET_COUNTER = Counter('counter_get_requests_total', 'Total GET requests to read the counter')

# Routes
@app.route("/", methods=["GET"])
def get_counter():
    value = read_counter()
    GET_COUNTER.inc()
    logger.info(f"GET / - Counter value: {value}")
    return jsonify({"counter": value, "version": VERSION})

@app.route("/", methods=["POST"])
def increment_counter():
    old_value = read_counter()
    value = old_value + 1
    write_counter(value)
    POST_COUNTER.inc()
    logger.info(f"POST / - Counter incremented: {old_value} -> {value}")
    return jsonify({"counter": value})

@app.route("/healthz", methods=["GET"])
def health():
    logger.info("Health check passed")
    return "ok", 200

@app.route("/metrics")
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

@app.errorhandler(500)
def error_handler(error):
    logger.error(f"Server error: {str(error)}")
    return jsonify({"error": "Internal server error"}), 500

if __name__ == "__main__":
    logger.info("Starting Flask app on 0.0.0.0:5000")
    app.run(host="0.0.0.0", port=5000)
