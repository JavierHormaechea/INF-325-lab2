# INF-325 Laboratorio 2: MongoDB (Base de Datos Documental y Vectorial)

Este proyecto implementa una base de datos local en MongoDB configurada como un **Replica Set** (1 Primario, 2 Secundarios) mediante Docker. Además, contiene scripts en Python para procesar un corpus de discursos históricos, transformarlos en embeddings (vectores espaciales) usando `SentenceTransformers`, y realizar búsquedas por similitud de coseno, simulando la base de un sistema RAG (Retrieval-Augmented Generation).

## Requisitos Previos

- **Docker** y **Docker Compose** instalados.
- **Python 3.10+** instalado.
- La carpeta `DiscursosOriginales` extraída con los archivos `.txt` en la raíz del proyecto.

## Pasos para Levantar el Proyecto

> **Nota para el equipo:** Dado que la base de datos corre de manera local en contenedores de Docker, los datos no se suben a GitHub. **Cada miembro del equipo que clone este repositorio deberá ejecutar este proceso de carga por primera vez** para poblar su propia base de datos local.

### 1. Levantar la Infraestructura de MongoDB

Inicia los contenedores y configura el clúster Replica Set ejecutando el script bash en la raíz del proyecto:

```bash
# Dar permisos de ejecución si es necesario
chmod +x init_replicaset.sh

# Ejecutar el script
./init_replicaset.sh
```

Este script se encarga de:
- Levantar 3 nodos (`mongo1`, `mongo2`, `mongo3`).
- Inicializar el clúster `rs0`.
- Crear la base de datos `Política` y la colección `Discursos`.

### 2. Configurar el Entorno de Python

El procesamiento de textos y la búsqueda requieren librerías de Machine Learning. Debes crear un entorno virtual e instalarlas:

```bash
cd scripts
python3 -m venv venv

# Activar el entorno virtual en Linux/Mac
source venv/bin/activate
# (Si estás en Windows usa: venv\Scripts\activate)

# Instalar las librerías
pip install -r requirements.txt
```

### 3. Configurar las Variables de Entorno

En la carpeta `scripts/`, crea un archivo llamado `.env` y coloca el siguiente contenido:

```env
# Conexión directa a localhost para evitar problemas de resolución de red de Docker desde el host
MONGO_URI=mongodb://localhost:27017/?directConnection=true

# Ruta donde se encuentran los archivos .txt originales
FILES_PATH=../DiscursosOriginales
```

### 4. Poblar la Base de Datos (Calcular Embeddings)

Este script leerá los 680 discursos, los convertirá en vectores y los insertará en MongoDB. 

```bash
# Asegúrate de estar en la carpeta scripts y con el entorno activado
python fill_DB.py
```
*Atención: Este proceso toma algunos minutos la primera vez, ya que debe descargar el modelo de lenguaje (aprox. 500MB) y procesar cada texto.*

### 5. Buscar Discursos por Similitud

Una vez finalizada la carga de datos, puedes probar el buscador semántico ejecutando:

```bash
# Búsqueda por defecto
python search.py

# Búsqueda personalizada
python search.py "el impacto de la guerra en la economía mundial"
```
El script generará el embedding de tu consulta, buscará contra todos los documentos de MongoDB y usará la fórmula de **Similitud Coseno** para devolverte los 5 discursos más relevantes ordenados por puntaje.