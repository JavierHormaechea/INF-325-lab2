#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"
SEED_URI='mongodb://mongo1:27017,mongo2:27017,mongo3:27017/?replicaSet=rs0'

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: Docker no está disponible en este sistema."
  exit 1
fi

if ! docker compose -f "$COMPOSE_FILE" ps >/dev/null 2>&1; then
  echo "ERROR: No se pudo consultar el proyecto de Docker Compose."
  exit 1
fi

COMPOSE_NETWORK="$(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{println $k}}{{end}}' mongo1 2>/dev/null | head -n1 | tr -d '[:space:]')"

if [[ -z "$COMPOSE_NETWORK" ]]; then
  echo "ERROR: No se pudo detectar la red de Docker del Replica Set."
  exit 1
fi

mongo_eval() {
  local js_code="$1"
  docker run --rm --network "$COMPOSE_NETWORK" mongo:7.0 mongosh "$SEED_URI" --quiet --eval "$js_code"
}

echo ">>> Detectando primario actual..."
CURRENT_PRIMARY_HOST="$(mongo_eval 'const hello = db.adminCommand({ hello: 1 }); if (!hello.primary) { quit(1); } print(hello.primary);' | tr -d '[:space:]')"
CURRENT_PRIMARY_CONTAINER="${CURRENT_PRIMARY_HOST%%:*}"

echo "    Primario actual: $CURRENT_PRIMARY_HOST"

echo ">>> Insertando documento de prueba previo al fallo..."
mongo_eval 'const db = db.getSiblingDB("Política"); db.Req4Demo.deleteMany({}); db.Req4Demo.insertOne({ _id: "before-failover", etapa: "antes_del_fallo", texto: "Documento de prueba para demostrar disponibilidad" }); print("    Inserción inicial completada");'

echo ">>> Deteniendo el primario para forzar failover..."
docker stop "$CURRENT_PRIMARY_CONTAINER" >/dev/null

echo ">>> Esperando elección de un nuevo primario..."
NEW_PRIMARY_HOST=""
for _ in $(seq 1 30); do
  NEW_PRIMARY_HOST="$(mongo_eval 'const hello = db.adminCommand({ hello: 1 }); if (hello.primary) { print(hello.primary); }' | tr -d '[:space:]' || true)"
  if [[ -n "$NEW_PRIMARY_HOST" && "$NEW_PRIMARY_HOST" != "$CURRENT_PRIMARY_HOST" ]]; then
    break
  fi
  sleep 2
done

if [[ -z "$NEW_PRIMARY_HOST" || "$NEW_PRIMARY_HOST" == "$CURRENT_PRIMARY_HOST" ]]; then
  echo "ERROR: No se detectó un nuevo primario después del failover."
  docker start "$CURRENT_PRIMARY_CONTAINER" >/dev/null || true
  exit 1
fi

echo "    Nuevo primario: $NEW_PRIMARY_HOST"

echo ">>> Verificando lectura y escritura con el nuevo primario..."
mongo_eval 'const db = db.getSiblingDB("Política"); db.Req4Demo.insertOne({ _id: "after-failover", etapa: "despues_del_fallo", texto: "Inserción exitosa tras el failover" }); print("    Escritura posterior al failover completada"); printjson(db.Req4Demo.find().toArray());'

echo ">>> Reiniciando el nodo original..."
docker start "$CURRENT_PRIMARY_CONTAINER" >/dev/null

echo ">>> Esperando que el nodo original vuelva al Replica Set..."
ORIGINAL_NODE_STATE=""
for _ in $(seq 1 30); do
  ORIGINAL_NODE_STATE="$(mongo_eval 'const status = rs.status(); const node = status.members.find(m => m.name === "'"$CURRENT_PRIMARY_HOST"'"); if (node) { print(node.stateStr); }' | tr -d '[:space:]' || true)"
  if [[ "$ORIGINAL_NODE_STATE" == "SECONDARY" || "$ORIGINAL_NODE_STATE" == "PRIMARY" ]]; then
    break
  fi
  sleep 2
done

echo ">>> Estado final del Replica Set..."
mongo_eval 'const status = rs.status(); status.members.forEach(m => print("  " + m.name + " -> " + m.stateStr));'

echo ""
echo "=== Demostración del requisito 4 finalizada ==="
echo "Se realizaron operaciones de lectura/escritura durante un cambio de primario."