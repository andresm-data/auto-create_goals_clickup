# Plantilla para Crear Metas en ClickUp
Automatiza la creación de metas y key results en ClickUp a partir de un archivo JSON local y un script Bash ejecutado desde terminal.

## Tabla de contenido

- [Descripción](#descripción)
- [Estructura](#estructura)
- [Instalación](#instalación)
- [Uso](#uso)

## Descripción

Este proyecto contiene una plantilla simple para crear metas de ClickUp de forma masiva usando la API oficial. El flujo actual está centrado en el archivo `create_goals.sh`, que lee un archivo `config.json` con una lista de personas o metas a crear, calcula la fecha de vencimiento al último segundo del mes correspondiente y luego envía solicitudes HTTP para registrar cada meta en ClickUp.

Por cada entrada del archivo de configuración, el script:

1. Lee datos como `team_id`, `owner_id`, `goal_name`, `goal_description`, `color` y `month_offset`.
2. Calcula la fecha de cierre de la meta usando el fin de mes del período indicado.
3. Crea la meta en ClickUp mediante la API `/team/{team_id}/goal`.
4. Recorre los `key_results` definidos y crea cada uno sobre la meta recién creada.
5. Muestra en consola el progreso, los identificadores creados y cualquier error devuelto por la API.

El repositorio está pensado como una base reutilizable: `config.json.example` se copia como `config.json`, se reemplazan los valores de ejemplo y se ejecuta el script con un token válido de ClickUp.

## Estructura

```text
.
├── config.json.example
├── create_goals.sh
└── LICENSE
```

Descripción de cada componente:

- `create_goals.sh`: script principal en Bash. Valida dependencias, carga la configuración, calcula fechas de vencimiento y realiza las llamadas a la API de ClickUp para crear metas y key results.
- `config.json.example`: archivo de ejemplo con la estructura esperada de configuración. Sirve como plantilla para construir el `config.json` real que consumirá el script.
- `LICENSE`: licencia del proyecto, actualmente GNU GPL v3.

## Instalación

Para usar este proyecto correctamente hay que preparar tanto el entorno local como la configuración de acceso a ClickUp.

Requisitos técnicos:

- Bash disponible en el sistema.
- `jq` instalado para procesar JSON.
- `curl` instalado para invocar la API de ClickUp.
- `date` con sintaxis GNU compatible con la opción `-d`.
- Un token de API de ClickUp con permisos para crear metas.

Aspectos a tener en cuenta:

- El script verifica explícitamente la presencia de `jq`.
- El script también valida que `date -d` funcione. En Linux normalmente ya está disponible.
- En macOS, el comando `date` nativo no siempre soporta `-d`; en ese caso suele requerirse `coreutils` para disponer de `gdate` o adaptar el script.
- El archivo de configuración real debe llamarse `config.json` y estar en la raíz del proyecto.

Preparación recomendada:

```bash
cp config.json.example config.json
chmod +x create_goals.sh
```

Antes de la ejecución, se debe editar `config.json` y reemplazar los datos de ejemplo por los IDs reales de equipo, propietario y contenido de metas.

También es recomendable exportar el token de ClickUp por variable de entorno:

```bash
export CLICKUP_API_TOKEN="tu_token_real"
```

## Uso

El flujo de uso actual es directo: el script procesa cada objeto del arreglo definido en `config.json` y crea una meta por registro.

Ejemplo de uso con comandos:

```bash
# 1. Crear el archivo de configuración real
cp config.json.example config.json

# 2. Dar permisos de ejecución al script
chmod +x create_goals.sh

# 3. Editar la configuración con los datos reales
nano config.json

# 4. Exportar el token de ClickUp
export CLICKUP_API_TOKEN="tu_token_real"

# 5. Ejecutar el script
./create_goals.sh
```

También es posible ejecutarlo en una sola línea después de preparar `config.json`:

```bash
CLICKUP_API_TOKEN="tu_token_real" ./create_goals.sh
```

Ejecutar:

```bash
./create_goals.sh
```

Comportamiento relevante:

- El archivo `config.json` debe contener un arreglo JSON.
- Cada elemento del arreglo representa una meta asociada a una persona o responsable.
- `month_offset` controla el mes objetivo. Por ejemplo, `0` usa el mes actual, mientras que `1` apunta al siguiente mes.
- La fecha de vencimiento se calcula automáticamente como el último segundo del mes objetivo.
- `key_results` debe contener una lista de objetos con al menos el campo `name`.
- El script muestra mensajes de progreso para cada meta y cada key result creado.
- Si la API devuelve un error, la respuesta se imprime en consola para facilitar diagnóstico.

Campos esperados por cada entrada de configuración:

- `person_name`: nombre descriptivo de la persona asociada a la meta.
- `owner_id`: ID del propietario en ClickUp.
- `team_id`: ID del equipo donde se creará la meta.
- `goal_name`: nombre visible de la meta.
- `goal_description`: descripción detallada de la meta.
- `month_offset`: desplazamiento del mes a usar para la fecha de vencimiento.
- `color`: color asociado a la meta.
- `key_results`: lista de resultados clave a crear.

Ejemplo de uso operativo:

1. Se copia el archivo de ejemplo a `config.json`.
2. Se completan los IDs y descripciones reales.
3. Se exporta `CLICKUP_API_TOKEN`.
4. Se ejecuta el script desde la raíz del proyecto.
5. Se revisa la salida en consola para confirmar IDs creados o errores de la API.