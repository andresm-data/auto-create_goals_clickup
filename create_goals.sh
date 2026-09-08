#!/bin/bash

# Configuración
CONFIG_FILE="config.json"
CLICKUP_API_BASE_URL="https://api.clickup.com/api/v2"

# Token de API de ClickUp
CLICKUP_API_TOKEN="${CLICKUP_API_TOKEN:-pk_123456}"

# --- Función para obtener el timestamp del último segundo del mes ---
get_end_of_month_timestamp() {
    local month_offset="$1"
    local current_year=$(date +%Y)
    local current_month=$(date +%m)

    # Calcula el mes y año objetivo
    local target_date_str=$(date -d "$current_year-$current_month-01 + $month_offset months" +"%Y-%m-01")
    local target_year=$(date -d "$target_date_str" +"%Y")
    local target_month=$(date -d "$target_date_str" +"%m")

    # Calcula el último día del mes objetivo
    local last_day_of_month_str=$(date -d "$target_year-$target_month-01 +1 month -1 day" +"%Y-%m-%d")

    # Obtiene el timestamp Unix (segundos) del último segundo de ese día
    local end_of_day_unix_timestamp=$(date -d "${last_day_of_month_str} 23:59:59" +%s)

    # Multiplica por 1000 para obtener milisegundos
    local end_of_day_ms=$((end_of_day_unix_timestamp * 1000))
    echo "$end_of_day_ms"
}
# -------------------------------------------------------------------

# Comprobar si jq está instalado
if ! command -v jq &> /dev/null
then
    echo "Error: 'jq' no está instalado. Por favor, instálalo para ejecutar este script."
    exit 1
fi

# Comprobar si el comando 'date' soporta la sintaxis de GNU (para -d)
if ! date -d "now" &>/dev/null; then
    echo "Error: Tu versión de 'date' no soporta la sintaxis de GNU (-d)."
    echo "Esto es común en macOS o BSD. Considera instalar 'coreutils' (gdate)."
    echo "En macOS: brew install coreutils"
    exit 1
fi

# Comprobar si el archivo de configuración existe
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: El archivo de configuración '$CONFIG_FILE' no se encontró."
    exit 1
fi

echo "Iniciando la creación de metas en ClickUp..."

# Leer y procesar cada persona del archivo de configuración
jq -c '.[]' "$CONFIG_FILE" | while read -r person_data; do
    team_id=$(echo "$person_data" | jq -r '.team_id')
    name=$(echo "$person_data" | jq -r '.person_name')
    goal_name=$(echo "$person_data" | jq -r '.goal_name')
    color=$(echo "$person_data" | jq -r '.color')
    goal_description=$(echo "$person_data" | jq -r '.goal_description')
    month_offset=$(echo "$person_data" | jq -r '.month_offset')
    key_results_data=$(echo "$person_data" | jq -c '.key_results')

    # Obtener el ID del propietario
    owner_id=$(echo "$person_data" | jq -r '.owner_id')

    echo "Procesando meta para: $name"

    # Calcular la fecha de vencimiento y el nombre de la meta
    due_date_ms=$(get_end_of_month_timestamp "$month_offset")

    echo "----------------------------------------------------"
    echo "Nombre de la Meta: $goal_name"
    echo "ID del Equipo: $team_id"
    echo "ID del Propietario: $owner_id"
    echo "Fecha de Vencimiento (Fin del mes): $(date -d "@$((due_date_ms / 1000))" +"%Y-%m-%d %H:%M:%S") (Timestamp: $due_date_ms)"

    # Construir el payload para la creación de la meta
    GOAL_PAYLOAD=$(jq -n \
        --arg name "$goal_name" \
        --arg description "$goal_description" \
        --arg due_date "$due_date_ms" \
        --arg owner_id "$owner_id" \
        --arg color "$color" \
        '{
            "name": $name,
            "description": $description,
            "due_date": $due_date,
            "owners": [$owner_id],
            "multiple_owners": false,
            "color": "$color"
        }')

    # Crear la meta
    echo "Creando meta '$goal_name'..."
    CREATE_GOAL_RESPONSE=$(curl -s -X POST \
        "${CLICKUP_API_BASE_URL}/team/${team_id}/goal" \
        -H "Authorization: ${CLICKUP_API_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$GOAL_PAYLOAD")

    GOAL_ID=$(echo "$CREATE_GOAL_RESPONSE" | jq -r '.goal.id')
    GOAL_STATUS=$(echo "$CREATE_GOAL_RESPONSE" | jq -r '.goal.status')

    if [ "$GOAL_ID" != "null" ]; then
        echo "Meta creada con éxito. ID de la Meta: $GOAL_ID, Estado: $GOAL_STATUS"

        # --- Crear Key Results para la meta ---
        if [ "$(echo "$key_results_data" | jq 'length')" -gt 0 ]; then
            echo "Creando Key Results para la meta '$goal_name'..."
            echo "$key_results_data" | jq -c '.[]' | while read -r kr_data; do
                kr_name=$(echo "$kr_data" | jq -r '.name')
                kr_task_id=$(echo "$kr_data" | jq -c '.task_id')
                KR_PAYLOAD=""

                # Verifica que task_id y list_ids sean arrays válidos
                KR_PAYLOAD=$(jq -n \
                    --arg name "$kr_name" \
                    --arg owner_id "$owner_id" \
                    --arg task_id "$TASK_ID" \
                    '{
                        "name": $name,
                        "type": "automatic",
                        "steps_start": 0,
                        "steps_end": 100,
                        "units": "tasks",
                        "owners": [$owner_id],
                        "task_ids": [],
                        "list_ids": []
                    }')

                echo "  - Creando Key Result: $kr_name"
                CREATE_KR_RESPONSE=$(curl -s -X POST \
                    "${CLICKUP_API_BASE_URL}/goal/${GOAL_ID}/key_result" \
                    -H "Authorization: ${CLICKUP_API_TOKEN}" \
                    -H "Content-Type: application/json" \
                    -d "$KR_PAYLOAD")

                KR_ID=$(echo "$CREATE_KR_RESPONSE" | jq -r '.key_result.id')
                if [ "$KR_ID" != "null" ]; then
                    echo "    Key Result '$kr_name' creado con éxito. ID: $KR_ID"
                else
                    echo "    Error al crear Key Result '$kr_name':" >&2
                    echo "$CREATE_KR_RESPONSE" | jq '.' >&2
                fi
            done
        else
            echo "No hay Key Results definidos para esta meta."
        fi

    else
        echo "Error al crear la meta '$goal_name':"
        echo "$CREATE_GOAL_RESPONSE" | jq '.' >&2
    fi
done

echo "Proceso completado."
