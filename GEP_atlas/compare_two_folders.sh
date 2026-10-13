#!/bin/bash

# Check the number of arguments
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 path_to_folder_1 path_to_folder_2"
  exit 1
fi

# Extract folder paths from arguments
path_to_folder_1="$1"
path_to_folder_2="$2"

# Check if both folders exist
if [ ! -d "$path_to_folder_1" ]; then
  echo "Folder $path_to_folder_1 does not exist."
  exit 1
fi

if [ ! -d "$path_to_folder_2" ]; then
  echo "Folder $path_to_folder_2 does not exist."
  exit 1
fi

# Find all folders in each directory
folders1=$(find "$path_to_folder_1" -maxdepth 1 -type d)
folders2=$(find "$path_to_folder_2" -maxdepth 1 -type d)

# Loop through each folder in the second directory and check if it exists in the first directory
for folder2 in $folders2; do
  folder2_name=$(basename "$folder2")
  
  if [ "$folder2_name" == "." ] || [ "$folder2_name" == ".." ]; then
    continue
  fi

  # Check if the folder exists in the first directory
  if ! echo "$folders1" | grep -q "$folder2_name"; then
    echo "$folder2_name is in $path_to_folder_2 but not in $path_to_folder_1"
  fi
done

