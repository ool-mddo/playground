#!/bin/bash

while true ; do
    echo "waiting NetBox init"
    curl -s -o /dev/null http://localhost:8000/
    if [ $? -eq 0 ]; then
        break
    fi
    sleep 5
done
