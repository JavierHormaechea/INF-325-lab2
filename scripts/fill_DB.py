import hashlib
import os
from pathlib import Path

from dotenv import load_dotenv
from pymongo import MongoClient
from pymongo.errors import DuplicateKeyError
from sentence_transformers import SentenceTransformer

# ── Configuración ─────────────────────────────────────────────────────────────
load_dotenv()

MONGO_URI  = os.getenv("MONGO_URI")
FILES_PATH = os.getenv("FILES_PATH")

if not MONGO_URI:
    raise EnvironmentError("Falta la variable MONGO_URI en el archivo .env")
if not FILES_PATH:
    raise EnvironmentError("Falta la variable FILES_PATH en el archivo .env")

# ── Conexión al Replica Set ───────────────────────────────────────────────────
client     = MongoClient(MONGO_URI)
db         = client["Política"]
collection = db["Discursos"]

# ── Modelo de embeddings ──────────────────────────────────────────────────────
model = SentenceTransformer("hiiamsid/sentence_similarity_spanish_es")


def process_document(file_path: Path) -> dict:
    """
    Lee un archivo .txt y devuelve el documento listo para insertar en MongoDB.
    """
    h = hashlib.sha256()
    lines = []

    with open(file_path, "r", encoding="utf-8") as f:
        for line in f:
            h.update(line.encode("utf-8"))
            lines.append(line)

    texto     = "".join(lines)
    sha256_id = h.hexdigest()
    embedding = model.encode(texto).tolist()   # numpy → list[float]

    return {
        "_id":       sha256_id,
        "texto":     texto,
        "embedding": embedding,
    }


# ── Inserción con upsert (idempotente) ────────────────────────────────────────
folder     = Path(FILES_PATH)
txt_files  = sorted(folder.glob("*.txt"))
total      = len(txt_files)
insertados = 0
omitidos   = 0

print(f"Procesando {total} archivo(s) en '{folder}'...\n")

for i, file_path in enumerate(txt_files, start=1):
    doc = process_document(file_path)

    # Upsert del documento usando el _id.
    result = collection.replace_one(
        {"_id": doc["_id"]},
        doc,
        upsert=True,
    )

    if result.upserted_id is not None:
        insertados += 1
        estado = "INSERTADO"
    else:
        omitidos += 1
        estado = "EXISTENTE"

    print(f"[{i:>4}/{total}] {estado}  _id={doc['_id'][:16]}…  {file_path.name}")

# ── Resumen ───────────────────────────────────────────────────────────────────
print(f"\n{'='*60}")
print(f"  Total procesados : {total}")
print(f"  Insertados       : {insertados}")
print(f"  Ya existían      : {omitidos}")
print(f"  Colección        : Política.Discursos")
print(f"{'='*60}")

client.close()