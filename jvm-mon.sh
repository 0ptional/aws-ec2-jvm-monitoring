#!/bin/bash

JSTAT_PROPS='
    [
        { "name": "s0c", "metricName": "JVMSurvivor0Capacity", "unit": "Kilobytes" },
        { "name": "s1c", "metricName": "JVMSurvivor1Capacity", "unit": "Kilobytes" },
        { "name": "s0u", "metricName": "JVMSurvivor0Utilization", "unit": "Kilobytes" },
        { "name": "s1u", "metricName": "JVMSurvivor1Utilization", "unit": "Kilobytes" },
        { "name": "ec", "metricName": "JVMEdenSpaceCapacity", "unit": "Kilobytes" },
        { "name": "eu", "metricName": "JVMEdenSpaceUtilization", "unit": "Kilobytes" },
        { "name": "oc", "metricName": "JVMOldSpaceCapacity", "unit": "Kilobytes" },
        { "name": "ou", "metricName": "JVMOldSpaceUtilization", "unit": "Kilobytes" },
        { "name": "pc", "metricName": "JVMCurrentPermanentSpaceCapacity", "unit": "Kilobytes" },
        { "name": "pu", "metricName": "JVMCurrentPermanentSpaceUtilization", "unit": "Kilobytes" },
        { "name": "ygc", "metricName": "JVMYoungGenerationGCEventCount", "unit": "Count" },
        { "name": "ygct", "metricName": "JVMYoungGenerationGCTime", "unit": "Seconds" },
        { "name": "fgc", "metricName": "JVMGCEventCount", "unit": "Count" },
        { "name": "fgct", "metricName": "JVMGCTime", "unit": "Seconds" },
        { "name": "gct", "metricName": "JVMTotalGCTime", "unit": "Seconds" }
    ]'

JSTAT_OUT=$(sudo jstat -gc `pgrep java` | tail -1)
IFS=" " read -ra JSTAT_OUT_ARRAY <<< "$JSTAT_OUT"

INSTANCE_ID=`wget -q -O - http://169.254.169.254/latest/meta-data/instance-id`


function get_stat_metric_name {
    echo $JSTAT_PROPS | jq -r --arg NAME "$1" '.[] | select(.name == $NAME) | .metricName'
}

function get_stat_metric_unit {
    echo $JSTAT_PROPS | jq -r --arg NAME "$1" '.[] | select(.name == $NAME) | .unit'
}

function get_stat_value {
    INDEX=$(echo $JSTAT_PROPS | jq --arg NAME "$1" 'to_entries | .[] | select(.value.name == $NAME) | .key')
    echo "${JSTAT_OUT_ARRAY[INDEX]}"
}



# handle input
STATS=

while [ "$1" != "" ]; do
    case $1 in
        -s | --stats )          shift
                                STATS=$1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

IFS=',' read -ra STATS_ARRAY <<< "$STATS"

# iterate stats that should be published
for stat in "${STATS_ARRAY[@]}"
do
    if [ $stat = "util" ]
    then
        # S0U+S1U+EU+OU
        METRIC_NAME="JVMMemoryUtilization"
        METRIC_UNIT="Kilobytes"

        S0U_VALUE=`get_stat_value "s0u"`
        S1U_VALUE=`get_stat_value "s1u"`
        EU_VALUE=`get_stat_value "eu"`
        OU_VALUE=`get_stat_value "ou"`

        METRIC_VALUE=$(awk '{printf "%.0f", $1+$2+$3+$4}' <<<"$S0U_VALUE $S1U_VALUE $EU_VALUE $OU_VALUE")

        echo "publishing metric for heap utilization (value=$METRIC_VALUE)"

        aws cloudwatch put-metric-data --metric-name $METRIC_NAME --namespace JVM --value $METRIC_VALUE --region eu-central-1 --dimensions "InstanceId=${INSTANCE_ID}" --unit $METRIC_UNIT --timestamp `date --utc +%FT%TZ`
    elif [ $stat = "capacity" ]
    then
        # S0C+S1C+EC+OC
        METRIC_NAME="JVMMemoryCapacity"
        METRIC_UNIT="Kilobytes"
        
        S0C_VALUE=`get_stat_value "s0c"`
        S1C_VALUE=`get_stat_value "s1c"`
        EC_VALUE=`get_stat_value "ec"`
        OC_VALUE=`get_stat_value "oc"`

        METRIC_VALUE=$(awk '{printf "%.0f", $1+$2+$3+$4}' <<<"$S0C_VALUE $S1C_VALUE $EC_VALUE $OC_VALUE")

        echo "publishing metric for heap capacity (value=$METRIC_VALUE)"

        aws cloudwatch put-metric-data --metric-name $METRIC_NAME --namespace JVM --value $METRIC_VALUE --region eu-central-1 --dimensions "InstanceId=${INSTANCE_ID}" --unit $METRIC_UNIT --timestamp `date --utc +%FT%TZ`
    else
        # individual metrics
        METRIC_NAME=`get_stat_metric_name "$stat"`
        STAT_VALUE=`get_stat_value "$stat"`
        METRIC_VALUE=$(awk '{printf "%.0f", $1}' <<<"$STAT_VALUE")
        METRIC_UNIT=`get_stat_metric_unit "$stat"`

        echo "publishing metric heap statistic '$stat' (value=$METRIC_VALUE, unit=$METRIC_UNIT)"

        aws cloudwatch put-metric-data --metric-name $METRIC_NAME --namespace JVM --value $METRIC_VALUE --region eu-central-1 --dimensions "InstanceId=${INSTANCE_ID}" --unit $METRIC_UNIT --timestamp `date --utc +%FT%TZ`
    fi
done

exit 0
