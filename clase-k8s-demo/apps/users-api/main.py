"""
Users API — Demo 2 y 3
Devuelve una lista simulada de usuarios e identifica el Pod que respondió.
El nombre del Pod viene de la variable de entorno POD_NAME (seteada por K8s).
"""
import os
from flask import Flask, jsonify

app = Flask(__name__)

POD_NAME = os.environ.get("POD_NAME", "unknown-pod")

USERS = [
    {"id": 1, "name": "Ana García",    "email": "ana@example.com"},
    {"id": 2, "name": "Carlos López",  "email": "carlos@example.com"},
    {"id": 3, "name": "María Rodríguez","email": "maria@example.com"},
]

@app.route("/users")
@app.route("/api/users")
def get_users():
    return jsonify({
        "data": USERS,
        "served_by": POD_NAME,   # ← clave para mostrar balanceo en Demo 3
        "service": "users-api",
    })

@app.route("/health")
def health():
    return jsonify({"status": "ok", "pod": POD_NAME})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
