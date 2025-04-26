#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Ошибка: требуется два аргумента."
    echo "Использование: $0 <входная_директория> <выходная_директория>"
    exit 1
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
        echo "Ошибка: не удалось создать выходную директорию '$OUTPUT_DIR'."
        exit 1
    fi
    echo "Создана выходная директория: $OUTPUT_DIR"
fi

get_unique_filename() {
    local base_filename="$1"
    local output_dir="$2"
    local name
    local extension
    local target_file
    local counter=1

    if [[ "$base_filename" == *.* ]]; then
        name="${base_filename%.*}"
        extension=".${base_filename##*.}"
    else
        name="$base_filename"
        extension=""
    fi

    target_file="$output_dir/$base_filename"

    while [ -e "$target_file" ]; do
        target_file="$output_dir/${name}${counter}${extension}"
        ((counter++))
    done

    basename "$target_file"
}

process_file() {
    local file="$1"

    base_filename=$(basename "$file")
    unique_filename=$(get_unique_filename "$base_filename" "$OUTPUT_DIR")

    cp "$file" "$OUTPUT_DIR/$unique_filename"

    if [ $? -eq 0 ]; then
        if [ "$unique_filename" != "$base_filename" ]; then
            echo "Файл '$file' скопирован как '$unique_filename'"
        fi
    else
        echo "Ошибка при копировании: $file"
    fi
}

echo "Начинаем копирование файлов из '$INPUT_DIR' в '$OUTPUT_DIR'..."

find "$INPUT_DIR" -type f | while read -r file; do
    process_file "$file"
done

echo "Копирование завершено!"

exit 0
