#!/bin/bash
#modified to run with marathon -bcajes

if [[ -z "$KAFKA_ADVERTISED_PORT" ]]; then
    #PORT0 should be the port that marathon assigned to this container
    export KAFKA_ADVERTISED_PORT=$PORT0
    echo "PORT0: $PORT0"
    echo "PORT1: $PORT1"
fi
if [[ -z "$KAFKA_ADVERTISED_HOST_NAME" ]]; then
    #$HOST should be the hostname of this docker host
    export KAFKA_ADVERTISED_HOST_NAME=$HOST
    echo "ADVERTISED_HOST: $KAFKA_ADVERTISED_HOST_NAME"
fi
if [[ -z "$KAFKA_BROKER_ID" ]]; then
    #ensure advertised ports are globally unique when running multiple brokers    
    #we are assuming here that HOST contains integers differentiating it from other node in the cluster
    export KAFKA_BROKER_ID=$(echo $HOST|sed 's/[^0-9]//g')
    echo "BROKER_ID: $KAFKA_BROKER_ID"
fi
if [[ -z "$KAFKA_LOG_DIRS" ]]; then
    export KAFKA_LOG_DIRS="/kafka/kafka-logs-$KAFKA_BROKER_ID"
fi
if [[ -z "$KAFKA_ZOOKEEPER_CONNECT" ]]; then
    export KAFKA_ZOOKEEPER_CONNECT=$(env | grep ZK.*PORT_2181_TCP= | sed -e 's|.*tcp://||' | paste -sd ,)
fi

if [[ -n "$KAFKA_HEAP_OPTS" ]]; then
    sed -r -i "s/^(export KAFKA_HEAP_OPTS)=\"(.*)\"/\1=\"$KAFKA_HEAP_OPTS\"/g" $KAFKA_HOME/bin/kafka-server-start.sh
    unset KAFKA_HEAP_OPTS
fi

for VAR in `env`
do
  if [[ $VAR =~ ^KAFKA_ && ! $VAR =~ ^KAFKA_HOME ]]; then
    kafka_name=`echo "$VAR" | sed -r "s/KAFKA_(.*)=.*/\1/g" | tr '[:upper:]' '[:lower:]' | tr _ .`
    env_var=`echo "$VAR" | sed -r "s/(.*)=.*/\1/g"`
    if egrep -q "(^|^#)$kafka_name=" $KAFKA_HOME/config/server.properties; then
        sed -r -i "s@(^|^#)($kafka_name)=(.*)@\2=${!env_var}@g" $KAFKA_HOME/config/server.properties #note that no config values may contain an '@' char
    else
        echo "$kafka_name=${!env_var}" >> $KAFKA_HOME/config/server.properties
    fi
  fi
done
echo "KAFKA_BROKER_ID is $KAFKA_BROKER_ID"
$KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server.properties
