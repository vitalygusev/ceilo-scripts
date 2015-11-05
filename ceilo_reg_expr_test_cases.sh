#!/bin/bash

source openrc

SETCOLOR_SUCCESS="echo -en \\033[1;32m"
SETCOLOR_FAILURE="echo -en \\033[1;31m"
SETCOLOR_NORMAL="echo -en \\033[0;39m"
SETCOLOR_REPORT="echo -en \\033[1;34m"

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

test_passed=0
test_failed=0
test_missed=0

echo "#####################################################################################"
echo "Query alarms by the part of alarm ID"
ceilometer alarm-threshold-create --name reg_expr -m image --period 10 --statistic avg --comparison-operator lt --threshold 0.9 1>/dev/null
id=$(ceilometer alarm-list | awk '/reg_expr/{print $2}')
part_of_id=$(echo $id | awk -F '-' '{print $1}')
list=$(ceilometer query-alarms -f "{\"=~\": {\"alarm_id\": \"$part_of_id\"}}")
check_empty "$?" $list

echo "#####################################################################################"
echo "Query alarm history by the part of alarm ID"
list=$(ceilometer query-alarm-history -f "{\"=~\": {\"alarm_id\": \"$part_of_id\"}}")
check_empty "$?" $list
ceilometer alarm-delete $id

echo "#####################################################################################"
echo "Query samples by the part of instance ID"
flavor=$(nova flavor-list | awk '/m1.micro/{print $2}')
image=$(glance image-list | awk '/TestVM/{print $2}')
net=$(neutron net-list | awk '/net04 /{print $2}')
nova boot reg_expr_test --image $image --flavor $flavor --nic net-id=$net 1>/dev/null
id=$(nova list | awk '/reg_expr_test/{print $2}')
part_of_id=$(echo $id | awk -F '-' '{print $1}')
list=$(ceilometer query-samples -f "{\"=~\": {\"resource_id\": \"$part_of_id\"}}")
check_empty "$?" $list
nova delete $id 1>/dev/null
echo "#####################################################################################"

test_count=$(($test_passed+$test_failed+$test_missed)) 

${SETCOLOR_REPORT}
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!!                                    !!"
echo "!!   The total number of tests:  $test_count    !!"
echo "!!   The number of passed tests: $test_passed    !!"
echo "!!   The number of failed tests: $test_failed    !!"
echo "!!   The number of missed tests: $test_missed    !!"
echo "!!                                    !!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
${SETCOLOR_NORMAL}
