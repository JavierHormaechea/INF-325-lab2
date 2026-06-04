#!/usr/bin/env bash
# =============================================================================
# init_replicaset.sh
# Levanta los contenedores MongoDB, inicializa el Replica Set "rs0" y
# crea la base de datos "Política" con la colección "Discursos".
# =============================================================================

set -euo pipefail

COMPOSE_FILE="$(dirname "$0")/docker-compose.yml"

# ── 1. Levantar contenedores ──────────────────────────────────────────────────
echo ">>> Levantando contenedores..."
docker compose -f "$COMPOSE_FILE" up -d

# ── 2. Esperar a que mongo1 esté listo ───────────────────────────────────────
echo ">>> Esperando a que mongo1 esté listo..."
until docker exec mongo1 mongosh --quiet --eval "db.adminCommand('ping').ok" 2>/dev/null | grep -q "1"; do
  echo "    mongo1 aún no está listo, reintentando en 3 s..."
  sleep 3
done
echo "    mongo1 está listo."

# ── 3. Inicializar el Replica Set ────────────────────────────────────────────
echo ">>> Inicializando Replica Set rs0..."
docker exec mongo1 mongosh --quiet --eval '
try {
  rs.status();
  print("Replica Set ya inicializado.");
} catch (e) {
  rs.initiate({
    _id: "rs0",
    members: [
      { _id: 0, host: "mongo1:27017", priority: 2 },
      { _id: 1, host: "mongo2:27017", priority: 1 },
      { _id: 2, host: "mongo3:27017", priority: 1 }
    ]
  });
}
'

# ── 4. Esperar a que el primario sea elegido ──────────────────────────────────
echo ">>> Esperando a que el primario sea elegido..."
until docker exec mongo1 mongosh --quiet --eval \
  "rs.status().members.some(m => m.stateStr === 'PRIMARY')" 2>/dev/null | grep -q "true"; do
  echo "    Elección en progreso, reintentando en 3 s..."
  sleep 3
done
echo "    Primario elegido."

# ── 5. Crear BD 'Política' y colección 'Discursos' ───────────────────────────
# Nota: el hash SHA-256 es el campo "_id" (índice único automático).
#       No se crea ningún índice hash separado.
echo ">>> Creando base de datos 'Política' y colección 'Discursos'..."
docker exec mongo1 mongosh --quiet "mongodb://mongo1:27017,mongo2:27017,mongo3:27017/?replicaSet=rs0" --eval '
db = db.getSiblingDB("Política");

// Crear la colección explícitamente
if (!db.getCollectionNames().includes("Discursos")) {
  db.createCollection("Discursos");
}

// Índice de texto sobre el campo "texto" para búsquedas full-text
db.Discursos.createIndex({ texto: "text" });

print("Base de datos y colección creadas exitosamente.");
print(db.getCollectionNames());
'

# ── 6. Verificación del estado final ─────────────────────────────────────────
echo ""
echo ">>> Estado del Replica Set:"
docker exec mongo1 mongosh --quiet --eval '
const status = rs.status();
status.members.forEach(m => {
  print("  " + m.name + " → " + m.stateStr);
});
'

echo ""
echo "=== Infraestructura lista ==="
echo "    Primario  : mongodb://localhost:27017"
echo "    Secundario: mongodb://localhost:27018"
echo "    Secundario: mongodb://localhost:27019"
echo "    Replica Set: rs0"
echo "    Base de datos: Política"
echo "    Colección    : Discursos"
echo ""
echo "Connection string para fill_DB.py:"
echo "    mongodb://mongo1:27017,mongo2:27017,mongo3:27017/?replicaSet=rs0"
