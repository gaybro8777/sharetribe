#!/bin/bash

set -e

# Expect to be passed either 'web' or 'worker' as parameter
APP_MODE="${1-web}"
CONTAINER_ALREADY_STARTED="CONTAINER_STARTED_ONCE"

case "$APP_MODE" in
    web)
        if [[ "$MAINTENANCE_MODE" == "true" ]] ; then
            exec /usr/sbin/nginx -p /opt/app -c config/nginx_maintenance.conf
        else
            rm -f tmp/pids/server.pid

            if [ ! -e $CONTAINER_ALREADY_STARTED ]; then
              touch $CONTAINER_ALREADY_STARTED
              echo "-- First container startup --"
              cp config/config.example.yml config/config.yml
              cp config/database.example.yml config/database.yml

              GEN_SECRETBASE=`exec bundle exec rake secret`
              echo "  secret_key_base: $GEN_SECRETBASE" >> config/config.yml
              bundle exec rake db:create db:structure:load && \
              bundle exec rake ts:index && \
              exec bundle exec passenger \
                 start \
                 -p "${PORT-3000}" \
                 --log-file "/dev/stdout" \
                 --min-instances "${PASSENGER_MIN_INSTANCES-1}" \
                 --max-pool-size "${PASSENGER_MAX_POOL_SIZE-1}"
            else
              echo "-- Not first container startup --"
            exec bundle exec passenger \
                 start \
                 -p "${PORT-3000}" \
                 --log-file "/dev/stdout" \
                 --min-instances "${PASSENGER_MIN_INSTANCES-1}" \
                 --max-pool-size "${PASSENGER_MAX_POOL_SIZE-1}"
            fi            
        fi
        ;;
    worker)
        if [[ "$MAINTENANCE_MODE" == "true" ]] ; then
            # Do nothing
            exec sleep 86400
        else
            if [ ! -e $CONTAINER_ALREADY_STARTED ]; then
              touch $CONTAINER_ALREADY_STARTED
              echo "-- First container startup --"
              cp config/config.example.yml config/config.yml
              cp config/database.example.yml config/database.yml

              GEN_SECRETBASE=`exec bundle exec rake secret`
              echo "  secret_key_base: $GEN_SECRETBASE" >> config/config.yml              
            else
              echo "-- Not first container startup --"
            fi
            exec bundle exec rake jobs:work
        fi
        ;;
    *)
        echo "Unknown process type. Must be either 'web' or 'worker'!"
        exit 1
        ;;
esac
