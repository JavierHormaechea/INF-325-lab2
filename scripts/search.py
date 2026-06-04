import os
import argparse
from dotenv import load_dotenv
from pymongo import MongoClient
from sentence_transformers import SentenceTransformer
import numpy as np
from sklearn.metrics.pairwise import cosine_similarity

# Cargar variables de entorno
load_dotenv()
MONGO_URI = os.getenv("MONGO_URI")

if not MONGO_URI:
    raise EnvironmentError("Falta la variable MONGO_URI en el archivo .env")

# Conectar a MongoDB
client = MongoClient(MONGO_URI)
db = client["Política"]
collection = db["Discursos"]

# Cargar el modelo
print("Cargando modelo de lenguaje...")
model = SentenceTransformer("hiiamsid/sentence_similarity_spanish_es")

def buscar_similares(consulta: str, top_k: int = 5):
    print(f"\nGenerando embedding para la consulta: '{consulta}'...")
    query_embedding = model.encode([consulta])[0]

    print("Obteniendo documentos de la base de datos...")
    documentos = list(collection.find({}, {"_id": 1, "texto": 1, "embedding": 1}))
    
    if not documentos:
        print("La base de datos está vacía. Ejecuta fill_DB.py primero.")
        return

    doc_embeddings = np.array([doc["embedding"] for doc in documentos])
    query_embedding_2d = query_embedding.reshape(1, -1)

    print("Calculando similitudes...")
    similitudes = cosine_similarity(query_embedding_2d, doc_embeddings)[0]

    indices_top = np.argsort(similitudes)[::-1][:top_k]

    print("\n" + "="*80)
    print(f"TOP {top_k} DOCUMENTOS MÁS SIMILARES")
    print("="*80)

    for i, idx in enumerate(indices_top, 1):
        doc = documentos[idx]
        similitud = similitudes[idx]
        texto_recortado = doc["texto"][:300].replace("\n", " ").strip() + "..."
        print(f"\n[{i}] Similitud Coseno: {similitud:.4f}")
        print(f"    ID: {doc['_id']}")
        print(f"    Extracto: {texto_recortado}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Búsqueda semántica de discursos en MongoDB.")
    parser.add_argument("consulta", type=str, nargs="?", default="la importancia de la democracia y la libertad", help="Texto de la consulta para buscar")
    args = parser.parse_args()

    buscar_similares(args.consulta)
