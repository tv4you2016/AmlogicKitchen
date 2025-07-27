#!/bin/bash

set -e

# Add bin/ to LD_LIBRARY_PATH if not already present
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
[[ ":$LD_LIBRARY_PATH:" != *":$ROOT_DIR/bin:"* ]] && export LD_LIBRARY_PATH="$ROOT_DIR/bin${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

ARGS=()
while [[ $# -gt 0 ]]; do
    ARGS+=("$1")
    shift
done

IMAGE=${ARGS[0]}
PARTITION_NAME=${ARGS[1]}

if [ -z "$IMAGE" ] || [ ! -f "$IMAGE" ]; then
  exit 0
fi

for filename in level2/*.img; do
  part="$(basename "$filename" .img)"
  if [ -d level2/$part ]; then
    msize=$(du -sk level2/$part | cut -f1 | awk '{$1*=1024;$1=int($1*1.08);printf $1}')
    #echo "make_Super.sh -> Creating $part image size: $msize"
    [ $msize -lt 1048576 ] && msize=1048576
    echo "make_Super.sh -> Creating $part image size: $msize"
    #./common/make_image.sh -r $part $msize level2/$part level2/${part}.img
    echo "Done."
  fi
done

supertype=$(cat level2/config/super_type.txt 2>/dev/null)
if [ "$supertype" -eq "3" ] 2>/dev/null || [ "$supertype" -eq "2" ] 2>/dev/null; then
  metadata_size=65536
  metadata_slot=$supertype
  supername="super"
  supersize=$(cat level2/config/super_size.txt)
  superusage=$(du -cb level2/*.img | grep total | cut -f1)
  command="bin/lpmake --metadata-size $metadata_size --super-name $supername --metadata-slots $metadata_slot"
  command="$command --device $supername:$supersize --group ${PARTITION_NAME}_dynamic_partitions:$superusage --group ${PARTITION_NAME}_dynamic_partitions_b:$superusage"



  for filename in level2/*.img; do
    part="$(basename "$filename" .img)"
    #size=$(du -skb level2/$part.img | cut -f1)
      
    # Check if the size file exists
    size_file="level2/config/${part}_size.txt"

    if [ -f "$size_file" ]; then
      size=$(<"$size_file")  # Read the size from the file
    else
      echo "Warning: $size_file not found. Using default size of 0."
      size=0  # Set a default size if the file does not exist
      command="$command --partition $part:readonly:$size:${PARTITION_NAME}_dynamic_partitions_b "
    fi
    
    # Ensure size is an integer and greater than 0
    if [[ $size =~ ^[0-9]+$ ]] && [ $size -gt 0 ]; then
      command="$command --partition $part:readonly:$size:${PARTITION_NAME}_dynamic_partitions --image $part=level2/$part.img"
    fi
  done

  if [ $superusage -ge $supersize ]; then
    echo "Unable to create super image, recreated images are too big."
    echo "Cleanup some files before retrying"
    echo "Needed space: $superusage"
    echo "Available maximum space: $supersize"
    exit 0
  fi

  command="$command --sparse --output $IMAGE.new"
  echo "Creating super image with command: $command"
  eval "$command"
fi
