"""
Products API — Demo 2 y 3
Devuelve una lista simulada de productos e identifica el Pod que respondió.
"""
import os
from flask import Flask, jsonify

app = Flask(__name__)

POD_NAME = os.environ.get("POD_NAME", "unknown-pod")

PRODUCTS = [
    {"id": 1, "name": "Laptop Pro",    "price": 1299.99, "stock": 15},
    {"id": 2, "name": "Monitor 4K",    "price":  499.99, "stock": 8},
    {"id": 3, "name": "Teclado Mecánico","price":  89.99, "stock": 42},
]

@app.route("/products")
@app.route("/api/products")
def get_products():
    return jsonify({
        "data": PRODUCTS,
        "served_by": POD_NAME,   # ← clave para mostrar balanceo en Demo 3
        "service": "products-api",
    })

@app.route("/health")
def health():
    return jsonify({"status": "ok", "pod": POD_NAME})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
