#!/bin/bash

usage() {
  echo "Usage: $0 <input_dir> <output_dir> [--max_depth <depth>]"
  exit 1
}

if [ $# -lt 2 ]; then
  usage
fi

INPUT_DIR="$1"
OUTPUT_DIR="$2"
MAX_DEPTH_FLAG=0
MAX_DEPTH=0

if [ $# -ge 3 ]; then

  if [ "$3" == "--max_depth" ] && [ $# -ge 4 ]; then
    MAX_DEPTH_FLAG=1
    MAX_DEPTH="$4"

    if ! [[ "$MAX_DEPTH" =~ ^[0-9]+$ ]]; then
      echo "Error: max depth must be a number."
      exit 1
    fi

  else
    echo "Error: unknown parameter $3"
    usage
  fi
fi

if [ ! -d "$INPUT_DIR" ]; then
  echo "Error: input directory does not exist."
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

path_depth() {
  local path="$1"
  local rel="${path#$INPUT_DIR/}"

  awk -F/ '{print NF}' <<< "$rel"
}

copy_with_structure() {
  local src="$1"
  local dest="$2"

  for item in "$src"/*; do
    if [ -f "$item" ]; then
      local rel_path="${item#$INPUT_DIR/}"
      local depth=$(path_depth "$item")
      local target_path=""

      if [ $MAX_DEPTH_FLAG -eq 1 ] && [ "$depth" -gt "$MAX_DEPTH" ]; then
        local cut_levels=$((depth - MAX_DEPTH))

        IFS='/' read -ra parts <<< "$rel_path"
        new_parts=("${parts[@]:$cut_levels}")
        target_path="${new_parts[*]}"
        target_path="${target_path// //}"
      else
        target_path="$rel_path"
      fi

      mkdir -p "$dest/$(dirname "$target_path")"
      cp "$item" "$dest/$target_path"
    elif [ -d "$item" ]; then
      copy_with_structure "$item" "$dest"
    fi
  done
}

echo "Копирование файлов из '$INPUT_DIR' в '$OUTPUT_DIR'..."
copy_with_structure "$INPUT_DIR" "$OUTPUT_DIR"
echo "Копирование завершено!"

exit 0
