# INF-325 Laboratorio 2: MongoDB — Base de Datos Documental y Vectorial

Proyecto del curso **Bases de Datos Avanzadas (INF-325)** que implementa un sistema de búsqueda semántica sobre un corpus de 680 discursos políticos chilenos, utilizando MongoDB como base de datos vectorial y documental.

## ¿Qué hace este proyecto?

1. **Cluster de Alta Disponibilidad:** Levanta 3 instancias de MongoDB configuradas como un Replica Set (`rs0`) mediante Docker, con 1 nodo Primario y 2 Secundarios.
2. **Preprocesamiento e Inserción:** Lee los 680 archivos `.txt` del corpus, genera un identificador SHA-256 por cada uno, calcula su embedding (vector de 768 dimensiones) usando un modelo de lenguaje en español, y los almacena en MongoDB.
3. **Búsqueda Semántica:** Recibe una consulta en texto libre, la vectoriza con el mismo modelo, y devuelve los 5 discursos más relevantes ordenados por similitud de coseno.
4. **Tolerancia a Fallos:** Incluye un script que demuestra automáticamente que el sistema sigue operativo (lectura y escritura) incluso cuando el nodo primario se cae, evidenciando la elección automática de un nuevo primario.

## Estructura del Proyecto

```
INF-325-lab2/
├── docker-compose.yml            # Define los 3 nodos de MongoDB
├── init_replicaset.sh            # Levanta Docker e inicializa el Replica Set
├── scripts/
│   ├── fill_DB.py                # Procesa los discursos y los inserta en la BD
│   ├── search.py                 # Script de búsqueda semántica
│   ├── req4_failover_demo.sh     # Demostración de Alta Disponibilidad (Req 4)
│   ├── requirements.txt          # Dependencias de Python
│   └── .env                      # Variables de entorno (no se sube a Git)
├── DiscursosOriginales/          # Corpus de 680 discursos .txt (no se sube a Git)
├── .gitignore
└── README.md
```

## Requisitos Previos

- **Docker** y **Docker Compose** instalados y funcionando.
- **Python 3.10+** instalado.
- La carpeta `DiscursosOriginales/` con los 680 archivos `.txt`, ubicada en la raíz del proyecto.

## Instrucciones para Levantar el Proyecto

> **Importante:** La base de datos corre localmente dentro de contenedores Docker, por lo que los datos **no se suben a GitHub**. Cada persona que clone este repositorio deberá ejecutar todo este proceso una vez para poblar su propia base de datos local.

### Paso 1 — Levantar la Infraestructura de MongoDB

```bash
chmod +x init_replicaset.sh
./init_replicaset.sh
```

Este script levanta los 3 contenedores, inicializa el Replica Set `rs0`, y crea la base de datos `Política` con la colección `Discursos`.

### Paso 2 — Crear el Entorno Virtual de Python

```bash
cd scripts
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

> En Windows usar `venv\Scripts\activate` en lugar de `source venv/bin/activate`.

### Paso 3 — Configurar las Variables de Entorno

Dentro de la carpeta `scripts/`, crea un archivo llamado `.env` con el siguiente contenido:

```env
MONGO_URI=mongodb://localhost:27017/?directConnection=true
FILES_PATH=../DiscursosOriginales
```

### Paso 4 — Poblar la Base de Datos

```bash
python3 fill_DB.py
```

> **⏳ Este proceso tarda varios minutos** (entre 15 y 40 min dependiendo de tu computador). Esto es normal y esperado: el script debe cargar un modelo de Inteligencia Artificial (~500 MB) que convierte cada discurso en un vector matemático de 768 dimensiones (embedding). Este cálculo se hace localmente en tu CPU para cada uno de los 680 archivos de texto, lo cual es computacionalmente intensivo. Solo es necesario hacerlo una vez; después de esto, los datos quedan almacenados en los volúmenes de Docker y persisten entre reinicios.

### Paso 5 — Realizar Búsquedas Semánticas

Con el entorno virtual activado y dentro de la carpeta `scripts/`:

```bash
# Búsqueda con texto personalizado
python3 search.py "el impacto de la guerra en la economía mundial"

# Búsqueda con texto por defecto
python3 search.py
```

El script vectoriza tu consulta, la compara contra los 680 discursos almacenados usando **Similitud de Coseno**, y muestra los 5 más relevantes.

### Paso 6 — Demostración de Alta Disponibilidad (Requisito 4)

Para demostrar que el Replica Set sigue respondiendo ante la caída del nodo primario:

```bash
chmod +x scripts/req4_failover_demo.sh
./scripts/req4_failover_demo.sh
```

Este script automáticamente:
- Detecta cuál es el nodo primario actual.
- Inserta un documento de prueba.
- Detiene el nodo primario (simulando una falla).
- Espera la elección automática de un nuevo primario.
- Verifica que la lectura y escritura siguen funcionando.
- Reinicia el nodo caído y muestra el estado final del cluster.

## Tecnologías Utilizadas

| Tecnología | Uso |
|---|---|
| **MongoDB 7.0** | Base de datos documental y vectorial |
| **Docker / Docker Compose** | Orquestación del Replica Set (3 nodos) |
| **Python 3** | Scripts de procesamiento y búsqueda |
| **sentence-transformers** | Generación de embeddings en español |
| **scikit-learn** | Cálculo de similitud de coseno |
| **pymongo** | Driver de conexión a MongoDB |

## Capturas de Evidencia

La carpeta `CapturasEvidencia/` contiene capturas de pantalla que demuestran el correcto funcionamiento de cada requisito del laboratorio.

| Captura | Archivo | Qué demuestra |
|---|---|---|
| **0** | `0_inicializacionRS.png` | **Inicialización del Replica Set.** Muestra la ejecución de `init_replicaset.sh`: se levantan los 3 contenedores Docker (mongo1, mongo2, mongo3), se inicializa el Replica Set `rs0`, se crea la base de datos `Política` con la colección `Discursos`, y se confirma que mongo1 es PRIMARY y los otros dos son SECONDARY. |
| **1** | `1_contenedores.png` | **Estado del cluster en operación normal.** Muestra con `docker ps` que los 3 contenedores están corriendo con estado `healthy`, y con `rs.status()` que el Replica Set tiene los roles correctos: 1 PRIMARY + 2 SECONDARY. |
| **2a** | `2_fillDB.png` | **Procesamiento e inserción de discursos (inicio).** Muestra el comienzo de la ejecución de `fill_DB.py`: se carga el modelo de lenguaje, y se procesan los 680 archivos `.txt` del corpus. En esta segunda ejecución todos aparecen como `EXISTENTE`, lo que demuestra la **idempotencia** del script (no inserta duplicados gracias al SHA-256 como `_id`). |
| **2b** | `2_fillDB_idempotencia.png` | **Resumen final de la inserción.** Muestra las últimas líneas de `fill_DB.py` con el conteo final: `Total procesados: 680`, `Insertados: 0`, `Ya existían: 680`. Esto confirma que los 680 archivos fueron procesados correctamente y que la base de datos ya contenía todos los documentos. |
| **3** | `3_estructuraDocumento.png` | **Estructura de un documento en MongoDB.** Consulta directa a la base de datos que muestra un documento real con sus 3 campos: `_id` (hash SHA-256 de 64 caracteres), `texto` (primeros 150 caracteres del discurso), y `embedding` (vector de 768 dimensiones con valores flotantes). Confirma que hay 679 documentos únicos en la colección (680 archivos menos 1 duplicado en el corpus original). |
| **4** | `4_BusquedaSemantica.png` | **Búsqueda semántica funcionando.** Muestra la ejecución de `search.py` con la consulta *"la importancia de la educación para el desarrollo del país"*. El sistema devuelve los 5 discursos más relevantes ordenados por Similitud de Coseno (puntajes entre 0.48 y 0.51), con extractos del texto que confirman la relevancia temática de los resultados. |
| **5-6** | `5_6_AltaDisponibilidad.png` | **Demostración completa de Alta Disponibilidad (failover).** Muestra la ejecución de `req4_failover_demo.sh`: se detecta que mongo1 es el primario, se inserta un documento de prueba, se detiene mongo1 simulando una falla, mongo2 es elegido automáticamente como nuevo primario, se verifica que la lectura y escritura siguen funcionando (se muestran los documentos `before-failover` y `after-failover`), se reinicia mongo1 y se confirma que vuelve al cluster como SECONDARY. |
| **7** | `7_idempotencia.png` | **Detección de duplicados e idempotencia.** Muestra que la base de datos contiene 679 documentos únicos a pesar de que el corpus tiene 680 archivos. Esto se debe a que los archivos `85835.txt` y `85836.txt` tienen contenido idéntico y generan el mismo hash SHA-256 (`f1a9efcd...`), por lo que el sistema los almacena una sola vez, evitando redundancia automáticamente. |