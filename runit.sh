#!/bin/bash

#success:0 fail:1
set -o pipefail

# environment
SPORT=8080
COLOR_ARRAY=('32' '33' '34' '35' '36')

# variable
procfile=""
envfile=""


#  usage
function usage() {
    echo "Usage: runit [-c] [-f procfile|Procfile] [-e envfile|.env]
             -c: check procfile and envfile
             -f: load the procfile
             -e: load the envfile
             -h: help information
             "
}



function verify_env() {
    local envfile="$1"
    local ret_val=0

    if [[ ! -f $envfile ]]; then
        echo $envfile": The file is not exist"
        exit 1
    fi

    # 验证envfile格式
    while read line
    do
        if [[ $(echo ${line} | grep "^#") ]]; then
            continue
        elif [[ ${line} == "" ]]; then
            continue
        else
            :
        fi
		
        key="${line%%=*}"
        value="${line#*=}"

        # envfile格式不对，没有等号
        if [[ $(echo ${line} | grep "=") ]]; then
            echo $key" : 没有等号"
            ret_val=1
        fi

        # envfile键名中含有非法字符
        if [[ $(echo ${key} | grep -v "[^a-zA-Z0-9_]") ]]; then
            echo $key" : 含有非法字符"
            ret_val=1
        fi

        # envfile不存在value
        if [[ ${value} == "" ]]; then
            echo ${key}" : 不存在value"
            ret_val=1
        fi

        # envfile value包含空白
        if [[ $(echo ${value} | grep " ") ]]; then
            echo ${key}" : 包含空白"
            ret_val=1
        fi

        if [[ ${key} != "bar" && ${value} == "42" ]]; then
            echo "42 does not contain: bar"
        fi
    done < $envfile
	return ${ret_val}
}

function verify_proc() {
	local procfile=$1
	local ret_val=0
	
    if [[ ! -f $procfile ]]; then
        echo $procfile": The file is not exist"
        exit 1
    fi

    # 验证proffile格式是否正确
    while read line
    do
        if [[ $(echo ${line} | grep "^#") ]]; then
            continue
        elif [[ ${line} == "" ]]; then
            continue
        else
            :
        fi

        procname="${line%%=*}"
        proccmd="${line#*=}"
        echo $procname" : "$proccmd

        # procfile格式不对，没有冒号
        if [[ $(echo ${line} | grep -v ":") ]]; then
            echo $procname": 没有冒号"
            ret_val=1
        fi

        # procfile进程名称含有非法字符
        if [[ $(echo ${procname} | grep -v "[^a-zA-Z0-9_]") ]]; then
            echo $procname": 含有非法字符"
            ret_val=1
        fi

    done < $procfile
	return ${ret_val}
}


function log() {
    local name="$1"
    local command="$2"
    local color="$3"
    cur_time=$(date +%H:%M:%s)

    printf "\E[${color}m${cur_time} %-7s] | " "${name}"

    tput sgr0
    echo "${command}"
    return 0
}


function run_command() {
    local number="1"
    local proc_name="$1"
    local command="$2"
    local cur_pid=$!
    local cur_color="${COLOR_ARRAY[$number]}"
    local comm_port=$(echo "${command}" | grep -e "\$PORT")

    [[ -n "${comm_port}" ]] && [[ -z "${PORT}" ]] && PORT=8080
    
	bash -c "${command}" > >(
        while read result; do
            log "${proc_name}" "${result}" "${COLOR}"
        done
    ) 2>&1 &

    local output="$(eval echo \"${command}\")"
    log "${proc_name}" "${output} start with pid ${cur_pid}" "${cur_color}"
    if [[ $? -ne 0 ]] ;then
		return 1
	fi
	
    if [[ -n "${comm_port}" ]] ;then 
		PORT=$((${PORT} + 1))
	fi
	
    (( number ++ ))

    return 0
}


function load_env_file() {
    set -a
    local env_lists="$1"
    for flag in $(echo "${env_lists}"); do
        [[ -f "${flag}" ]] && source "${flag}"
    done
    return 0
}


function run_procfile() {
    local proc_file="$1"
    [[ ! -f "${proc_file}" ]] && echo "this procfile is not exists" && return 1
    while read line; do
        if echo "${line}" | grep -qv ":"; then
            echo "no_colon_command"
            continue
        fi
        local key="${line%%:*}"
        local value="${line#*:}"
        [[ -n "${key}" ]] && [[ -n "${value}" ]] && run_command "${key}" "${value}"
        [[ $? -ne 0 ]] && return 1
    done < <(grep "" "${proc_file}" | grep -vE "[[:space:]]*#" | grep -v "^$" )
    wait
    return 0
}


function main() {
    local check=false
    while getopts "f:e:ch" flag
    do
        case ${flag} in
            c) check=true ;;
            f) procfile="${OPTARG}" ;;
            e) envfile="${OPTARG}" ;;
            *) usage ;;
        esac
    done

    if ${check}; then
        if [[ -n "${procfile}" ]]; then
            verify_proc "${procfile}"
            PROC_RET_VALUE=$?
            [[ ${PROC_RET_VALUE} -ne 0 ]] && exit 1
        else
            echo "The procfile is null"
            exit 1
        fi

        if [[ -z "${envfile}" ]];then
            envfile="./.env"
        fi
        verify_env  "${envfile}"
        ENV_RET_VALUE=$?
        [[ ${ENV_RET_VALUE} -ne 0 ]] && exit 1

    else
        if [[ -z "${envfile}" ]]; then
            envfile="./.env"
        fi

        load_env_file "${envfile}"
        LOAD_ENV_RET_VALUE=$?
        [[ ${LOAD_ENV_RET_VALUE} -ne 0 ]] && exit 1

        if [[ -z "${procfile}" ]]; then
            procfile="./Procfile"
        fi

        run_procfile "${procfile}"
        RUN_RET_VALUE=$?
        [[ RUN_RET_VALUE -ne 0 ]] && exit 1
    fi
    exit 0
} 

main "$@"
