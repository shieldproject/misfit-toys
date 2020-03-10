#!/bin/bash

echo ">> STARTING SHIELD LOAD TEST"
for TARGETNUMBER in {0..3}
do
    echo ">> configuring SHIELD"
    cat <<EOF | spruce merge - | shield import -
---
core:  $SHIELD_CORE
token: $SHIELD_AUTH_TOKEN
tenants:
  - name: Other Tenant
    storage:
      - name:    CloudStor
        summary: Just a regualr webdav store
        agent:   127.0.0.1:5444
        plugin:  webdav
        config:
          url:   http://127.0.0.1:8182
    
    systems:
      - name:    target-$TARGETNUMBER
        summary: Just a test target
        agent:   127.0.0.1:5444
        plugin:  fs
        config:
          base_dir: /
        
        jobs:
          - name:    Test backup 1
            when:    hourly 1
            paused:  no
            storage: CloudStor
            retain:  1d

          - name:    Test backup 2
            when:    hourly 1
            paused:  no
            storage: CloudStor
            retain:  1d

          - name:    Test backup 3
            when:    hourly 1
            paused:  no
            storage: CloudStor
            retain:  1d 
EOF
done
