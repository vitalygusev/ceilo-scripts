#!/bin/bash

source ~/openrc

SETCOLOR_SUCCESS="echo -en \\033[1;32m"
SETCOLOR_FAILURE="echo -en \\033[1;31m"
SETCOLOR_NORMAL="echo -en \\033[0;39m"
SETCOLOR_REPORT="echo -en \\033[1;34m"

test_passed=0
test_failed=0
test_missed=0
alarm_create="false"

echo_ok() {
    msg=$1
    ${SETCOLOR_SUCCESS}
    echo "$(tput hpa $(tput cols))$(tput cub 6)[OK]"
    echo "Test passed"
    ${SETCOLOR_NORMAL}
    test_passed=$(($test_passed+1))
}

echo_fail() {
    ${SETCOLOR_FAILURE}
    echo "$(tput hpa $(tput cols))$(tput cub 6)[FAIL]"
    echo "Test failed"
    ${SETCOLOR_NORMAL}
    test_failed=$(($test_failed+1))
}

check_return_code_after_command_execution() {
    if [ "$1" -ne 0 ]; then
        echo_fail
    else
        echo_ok
    fi
}

check_empty() {
    if [ -z "$2" ]; then
        echo_fail
    else 
        check_return_code_after_command_execution "$1"
    fi
}

echo "#####################################################################################"
echo "Resource list"
list=$(ceilometer resource-list)
check_empty "$?" $list

echo "#####################################################################################"
echo "Resource show"
resource=$(ceilometer resource-show $(ceilometer resource-list | awk '(NR == 4) {print $2}'))
check_empty "$?" $resource

echo "#####################################################################################"
echo "Meter list"
list=$(ceilometer meter-list)
check_empty "$?" $list

echo "#####################################################################################"
echo "Samples list"
list=$(ceilometer sample-list --limit 5  -m $(ceilometer meter-list | awk '(NR == 4) {print $2}'))
check_empty "$?" $list

echo "#####################################################################################"
echo "Samples query"
query=$(ceilometer query-samples -f "{\"and\": [{\"=\":{\"counter_name\": \"$(ceilometer meter-list | awk '(NR == 4) {print $2}')\"}}, {\">\":{\"counter_volume\":0}}]}" -l 5)
check_empty "$?" $query

echo "#####################################################################################"
echo "Samples post"
sample=$(ceilometer sample-list -m $(ceilometer meter-list | awk '(NR == 4) {print $2}') | awk '(NR == 4)') && ceilometer sample-create -m $(echo $sample | awk '{print $4}') -r 111111 --meter-type $(echo $sample | awk '{print $6}') --meter-unit $(echo $sample | awk '{print $10}') --sample-volume $(echo $sample | awk '{print $8}') 1>/dev/null
check_return_code_after_command_execution "$?"

echo "#####################################################################################"
echo "Statistics list"
list=$(ceilometer statistics -m $(ceilometer meter-list | awk '(NR == 4) {print $2}'))
check_empty "$?" $list

echo "#####################################################################################"
echo "Alarm post"
ceilometer alarm-threshold-create --name alarm_test_plan_1 -m image --period 10 --statistic avg --comparison-operator lt --threshold 0.9 1>/dev/null && ceilometer alarm-threshold-create --name alarm_test_plan_2 -m image --period 10 --statistic avg --comparison-operator lt --threshold 1.1 1>/dev/null
st=$?
if [ $st -eq 0 ]; then
    alarm_create="true"
fi
check_return_code_after_command_execution $st

if [ $alarm_create == "true" ]; then

    echo "#####################################################################################"
    echo "Alarm combination post"
    ceilometer alarm-combination-create --name alarm_comb_test_plan --alarm_ids $(ceilometer alarm-list | awk '/alarm_test_plan_1/{print $2}') --alarm_ids $(ceilometer alarm-list | awk '/alarm_test_plan_2/{print $2}') 1>/dev/null
    check_return_code_after_command_execution "$?"
    
    echo "#####################################################################################"
    echo "Alarm list"
    list=$(ceilometer alarm-list)
    check_empty "$?" $list
    
    echo "#####################################################################################"
    echo "Alarm get"
    alarm=$(ceilometer alarm-show $(ceilometer alarm-list | awk '/alarm_test_plan_2/{print $2}'))
    check_empty "$?" $alarm
    
    echo "#####################################################################################"
    echo "Alarm put"
    ceilometer alarm-threshold-update $(ceilometer alarm-list | awk '/alarm_test_plan_2/{print $2}') --name update_alarm_test_plan_2 --period 20 --threshold 2 1>/dev/null
    check_return_code_after_command_execution "$?"

    echo "#####################################################################################"
    echo "Alarm combination put"
    ceilometer alarm-combination-update $(ceilometer alarm-list | awk '/alarm_comb_test_plan/{print $2}') --severity moderate 1>/dev/null
    check_return_code_after_command_execution "$?"
    
    echo "#####################################################################################"
    echo "Alarm get state"
    ceilometer alarm-state-get $(ceilometer alarm-list | awk '/alarm_test_plan_2/{print $2}') 1>/dev/null
    check_return_code_after_command_execution "$?"
    
    echo "#####################################################################################"
    echo "Alarm set state"
    state=$(ceilometer alarm-state-set $(ceilometer alarm-list | awk '/alarm_test_plan_2/{print $2}') --state 'insufficient data' 1>/dev/null && ceilometer alarm-state-get $(ceilometer alarm-list | awk '/alarm_test_plan_2/{print $2}') | grep 'insufficient data')
    check_empty "$?" $state
    
    echo "#####################################################################################"
    echo "Alarm get history"
    query=$(ceilometer alarm-history $(ceilometer alarm-list | awk '/alarm_test_plan_2/{print $2}'))
    check_empty "$?" $query
    
    echo "#####################################################################################"
    echo "Alarm query history"
    query=(ceilometer query-alarm-history -f "{\"and\":[{\"<\":{\"timestamp\":\"$(date +%Y-%m-%dT%H:%M:%S)\"}},{\">\":{\"timestamp\":\"2000-01-01T01:01:01\"}},{\"=\":{\"type\":\"state transition\"}},{\"=\":{\"alarm_id\":\"$(ceilometer alarm-list | awk '/alarm_test_plan_2/{print $2}')\"}}]}")
    check_empty "$?" $query
    
    echo "#####################################################################################"
    echo "Alarm query"
    alarms=$(ceilometer query-alarms -f "{\"or\":[{\"=\":{\"state\":\"alarm\"}},{\"=\":{\"state\":\"ok\"}}]}")
    check_empty "$?" $alarms
    
    echo "#####################################################################################"
    echo "Alarm delete"
    ceilometer alarm-delete $(ceilometer alarm-list | awk '/alarm_test_plan_2/{print $2}') 1>/dev/null && ceilometer alarm-delete $(ceilometer alarm-list | awk '/alarm_test_plan/{print $2}') && ceilometer alarm-delete $(ceilometer alarm-list | awk '/alarm_comb_test_plan/{print $2}') 1>/dev/null
    check_return_code_after_command_execution "$?"
    echo "#####################################################################################"
else
    ${SETCOLOR_FAILURE}
    echo "Test for creating an alarm failed, so other tests for alarms will be skipped"
    ${SETCOLOR_NORMAL}
    test_missed=$(($test_missed+11))
fi

test_count=$(($test_passed+$test_failed+$test_missed)) 

${SETCOLOR_REPORT}
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!!                                    !!"
echo "!!   The total number of tests:  $test_count   !!"
echo "!!   The number of passed tests: $test_passed   !!"
echo "!!   The number of failed tests: $test_failed    !!"
echo "!!   The number of missed tests: $test_missed    !!"
echo "!!                                    !!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
${SETCOLOR_NORMAL}
