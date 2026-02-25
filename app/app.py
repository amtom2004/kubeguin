from flask import Flask, request, jsonify, redirect
import string
import random
import datetime
import os

app = Flask(__name__)

urls = {}

def generate_code(length=6):
    chars = string.ascii_letters + string.digits
    while True:
        code = ''.join(random.choices(chars, k=length))
        if code not in urls:
            return code

@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        "status": "healthy"
    }), 200

@app.route('/', methods=['GET'])
def home():
    return jsonify({
        "service": "URL Shortener",
        "version": os.getenv("APP_VERSION", "1.0.0"),
        "endpoints": {
            "POST /shorten": "Shorten a URL. Body: {\"url\": \"https://example.com\"}",
            "GET /<code>": "Redirect to original URL",
            "GET /stats/code": "Get click stats",
            "GET /all": "List all shortened URLs",
            "GET /health": "Health Check"
        }
    })

@app.route('/shorten', methods=['POST'])
def shorten():
    data = request.get_json()
    if not data or 'url' not in data:
        return jsonify({
            "error": "Missing URL in request body"
        }), 400
    
    original = data['url']
    custom = data.get('custom_code')

    if custom:
        if custom in urls:
            return jsonify({
                "error": f"Code '{custom}' already taken"
            }), 409
        code = custom
    else:
        code = generate_code()
    
    urls[code] = {
        "url": original,
        "created_at": datetime.datetime.now().isoformat(),
        "clicks": 0
    }

    host = request.host_url.rstrip('/')
    return jsonify({
        "short_url": f"{host}/{code}",
        "code": code,
        "original_url": original
    }), 201

@app.route('/stats/<code>', methods=['GET'])
def stats(code):
    if code not in urls:
        return jsonify({
            "error": "could n't found"
        }), 404
    entry = urls[code]
    return jsonify({
        "code": code,
        "original_url": entry["url"],
        "clicks": entry["clicks"],
        "created_at": entry["created_at"]
    })

@app.route('/all', methods=['GET'])
def list_all():
    host = request.host_url.rstrip('/')
    result = []
    for code, entry in urls.items():
        result.append({
            "short_url": f"{host}/{code}",
            "original_url": entry["url"],
            "clicks": entry["clicks"],
            "created_at": entry["created_at"]
        })
    return jsonify({
        "total": len(result),
        "urls": result
    })

@app.route('/<code>', methods=['GET'])
def redirect_url(code):
    if code not in urls:
        return jsonify({
            "error": "Code not found"
        }), 404
    urls[code]["clicks"] += 1
    return redirect(urls[code]["url"], code=302)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)