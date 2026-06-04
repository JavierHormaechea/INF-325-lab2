import hashlib
from pathlib import Path
from sentence_transformers import SentenceTransformer
import os
from dotenv import load_dotenv

# Esta funcion recibe el path del documento y retorna los 3 parametros a almacenar en la base de datos hash, texto y embedding
def process_documents(file_path, model):
    h = hashlib.sha256()
    file = open(file_path, "r", encoding="utf-8")
    text = ""
    for line in file:
        h.update(line.encode('utf-8'))
        text += line
    file.close()
    return h.hexdigest(), text, model.encode(text)

load_dotenv()

model = SentenceTransformer('hiiamsid/sentence_similarity_spanish_es')

folder = Path(os.getenv("FILES_PATH"))

for file in folder.glob("*.txt"):
    file_id, file_text, file_embedding = process_documents(file, model)
    print(file_id, file_embedding) ############ ACA VA SE TIENE QUE INSERTAR LOS DATOS EN LA BD