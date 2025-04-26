#!/bin/bash

usage() {
    echo "Использование: $0 [--max_depth N] <входная_директория> <выходная_директория>"
    echo "  --max_depth N  Сохранить структуру директорий до глубины N"
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
                echo "Ошибка: --max_depth требует числовой аргумент"
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
    echo "Ошибка: требуется два позиционных аргумента."
    usage
fi

INPUT_DIR="$1"
OUTPUT_DIR="$2"

if [ ! -d "$INPUT_DIR" ]; then
    echo "Ошибка: входная директория '$INPUT_DIR' не существует."
    exit 1
fi

if [ ! -d "$OUTPUT_DIR" ]; then
    mkdir -p "$OUTPUT_DIR"
    if [ $? -ne 0 ]; then
        echo "Ошикба: не удалось создать выходную директорию '$OUTPUT_DIR'."
        exit 1
    fi
    echo "Создана выходная директория: $OUTPUT_DIR."
fi

files_count=0
errors_count=0

get_unique_filename() {
    local base_path="$1"
    local filename="$2"
    local target_dir="$3"
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

    target_file="$target_dir/$base_path/$filename"
    while [ -e "$target_file" ]; do
        target_file="$target_dir/$base_path/${name}${counter}${extension}"
        ((counter++))
    done

    if [ -z "$base_path" ]; then
        echo "$(basename "$target_file")"
    else
        echo "$base_path/$(basename  "$target_file")"
    fi
}

process_file_with_depth() {
    local file="$1"
    local input_dir="$2"
    local output_dir="$3"
    local max_depth="$4"

    local rel_path="${file#$input_dir/}"
    local depth=$(echo "$rel_path" | tr -cd '/' | wc -c)
    local target_path=""

    if [ "$depth" -le "$max_depth" ]; then
        target_path=$(dirname "$rel_path")
    else
        target_path=$(echo "$rel_path" | cut -d'/' -f1-"$max_depth")
        if [ -f "$input_dir/$target_path" ]; then
            target_path=$(dirname "$target_path")
        fi
    fi

    if [ ! -z "$target_path" ] && [ "$target_path" != "." ]; then
        mkdir -p "$output_dir/$target_path"
        if [ $? -ne 0 ]; then
            echo "Ошибка: не удалось создать директорию '$output_dir/$target_path'"
            ((errors_count++))
            return
        fi
    else
        target_path=""
    fi

    local filename=$(basename "$file")
    local unique_path=$(get_unique_filename "$target_path" "$filename" "$output_dir")

    if [ -z "$target_path" ]; then
        cp "$file" "$output_dir/$unique_path"
    else
        cp "$file" "$output_dir/$unique_path"
    fi

    if [ $? -eq 0 ]; then
        echo "Файл '$file' скопирован как '$output_dir/$unique_path'"
        ((files_count++))
    else
        echo "Ошибка при копировании: $file"
        ((errors_count++))
    fi
}

process_file_flat() {
    local file="$1"
    local output_dir="$2"

    local base_filename=$(basename "$file")
    local unique_filename=$(get_unique_filename "" "$base_filename" "$output_dir")

    cp "$file" "$output_dir/$unique_filename"

    if [ $? -eq 0 ]; then
        if [ "$base_filename" != "$unique_filename" ]; then
            echo "Файл '$file' скопирован как '$unique_filename'"
        fi
        ((files_count++))
    else
        echo "Ошибка при копировании: $file"
        ((errors_count++))
    fi
}

echo "Начинаем копирование файлов из '$INPUT_DIR' в '$OUTPUT_DIR'..."

if $MAX_DEPTH_SET; then
    echo "Сохраняем структуру директорий до глубины $MAX_DEPTH"
    find "$INPUT_DIR" -type f | while read -r file; do
        process_file_with_depth "$file" "$INPUT_DIR" "$OUTPUT_DIR" "$MAX_DEPTH"
    done
else
    echo "Копируем все файлы в корень выходной директории"
    find "$INPUT_DIR" -type f | while read -r file; do
        process_file_flat "$file" "$OUTPUT_DIR"
    done
fi

echo "Копирование завершено!"
echo "Скопировано файлов: $files_count"

if [ $errors_count -gt 0 ]; then
    echo "Произошло ошибок: $errors_count"
    exit 1
fi

exit 0
