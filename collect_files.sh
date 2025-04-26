#!/bin/bash

usage() {
    echo "Использование: $0 [--max_depth N] <входная_директория> <выходная_директория>"
    echo "  --max_depth N  Ограничить уровень вложенности структуры директорий значением N"
    echo "                 (если не указано, все файлы копируются в корень выходной директории)"
    exit 1
}

MAX_DEPTH=""
MAX_DEPTH_SET=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --max_depth)
            if [[ "$2" =~ ^[0-9]+$ ]]; then
                MAX_DEPTH="$2"
                MAX_DEPTH_SET=true
                shift 2
            else
                echo "Ошибка: --max_depth требует числового аргумента"
                usage
            fi
            ;;
        -h|--help)
            usage
            ;;
        *)
            break
            ;;
    esac
done

if [ $# -ne 2 ]; then
    echo "Ошибка: требуется два позиционных аргумента (входная и выходная директории)."
    usage
fi

INPUT_DIR="$(realpath "$1")"
OUTPUT_DIR="$(realpath "$2")"

if [ ! -d "$INPUT_DIR" ]; then
    echo "Ошибка: входная директория '$INPUT_DIR' не существует."
    exit 1
fi

if [ ! -d "$OUTPUT_DIR" ]; then
    mkdir -p "$OUTPUT_DIR"
    if [ $? -ne 0 ]; then
        echo "Ошибка: не удалось создать выходную директорию '$OUTPUT_DIR'."
        exit 1
    fi
    echo "Создана выходная директория: $OUTPUT_DIR"
fi

duplicate_count=0

get_unique_filename() {
    local target_dir="$1"
    local filename="$2"
    local name
    local extension
    local target_file
    local counter=1

    if [[ "$filename" == *.* ]]; then
        name="${filename%.*}"
        extension=".${filename##*.}"
    else
        name="$filename"
        extension=""
    fi

    target_file="$target_dir/$filename"

    while [ -e "$target_file" ]; do
        target_file="$target_dir/${name}${counter}${extension}"
        ((counter++))
    done

    basename "$target_file"
}

process_with_max_depth() {
    local file="$1"
    local input_base="$2"
    local output_base="$3"
    local max_depth="$4"

    local rel_path="${file#$input_base/}"
    local filename=$(basename "$rel_path")
    local dir_path=$(dirname "$rel_path")

    if [ "$dir_path" = "." ]; then
        dir_path=""
    fi

    local depth=$(echo "$dir_path" | tr -cd '/' | wc -c)

    local target_dir_path
    if [ -z "$dir_path" ]; then
        target_dir_path="$output_base"
    elif [ "$depth" -lt "$max_depth" ]; then
        target_dir_path="$output_base/$dir_path"
    else
        local parts=($(echo "$dir_path" | tr '/' ' '))
        target_dir_path="$output_base"

        for ((i=0; i<max_depth; i++)); do
            if [ "${parts[$i]}" ]; then
                target_dir_path="$target_dir_path/${parts[$i]}"
            fi
        done
    fi

    mkdir -p "$target_dir_path"
    if [ $? -ne 0 ]; then
        echo "Ошибка: не удалось создать директорию '$target_dir_path'"
        ((errors_count++))
        return
    fi

    local unique_filename=$(get_unique_filename "$target_dir_path" "$filename")

    cp "$file" "$target_dir_path/$unique_filename"

    if [ $? -eq 0 ]; then
        if [ "$filename" != "$unique_filename" ]; then
            echo "Файл '$file' скопирован как '$target_dir_path/$unique_filename' (решен конфликт имен)"
            ((duplicate_count++))
        else
            echo "Файл '$file' скопирован в '$target_dir_path/$unique_filename'"
        fi
    else
        echo "Ошибка при копировании: $file"
    fi
}

process_flat() {
    local file="$1"
    local output_dir="$2"
    local filename=$(basename "$file")
    local unique_filename=$(get_unique_filename "$output_dir" "$filename")

    cp "$file" "$output_dir/$unique_filename"

    if [ $? -eq 0 ]; then
        if [ "$filename" != "$unique_filename" ]; then
            echo "Файл '$file' скопирован как '$output_dir/$unique_filename' (решен конфликт имен)"
        else
            echo "Файл '$file' скопирован в '$output_dir/$unique_filename'"
        fi
    else
        echo "Ошибка при копировании: $file"
    fi
}

echo "Начинаем копирование файлов из '$INPUT_DIR' в '$OUTPUT_DIR'..."

if $MAX_DEPTH_SET; then
    echo "Режим: сохранение структуры директорий до глубины $MAX_DEPTH"
    find "$INPUT_DIR" -type f | while read -r file; do
        process_with_max_depth "$file" "$INPUT_DIR" "$OUTPUT_DIR" "$MAX_DEPTH"
    done
else
    echo "Режим: все файлы копируются в корень выходной директории"
    find "$INPUT_DIR" -type f | while read -r file; do
        process_flat "$file" "$OUTPUT_DIR"
    done
fi

echo ""
echo "Копирование завершено!"

exit 0
