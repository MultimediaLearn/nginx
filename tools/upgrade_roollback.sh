#!/bin/bash
# 如果存在两个master，杀掉没有可用worker的那一套
set -x

NGX_TITLE="nginx"
NGX_PATH="sbin/nginx"

alive_check() {
    # 检查是否有正常接收连接的worker process
    num=`ps -eo pid,ppid,cmd | grep ${NGX_TITLE} | grep -v shutting | grep worker | wc -l`
    if [ $num -lt $1 ]; then
        echo "`date`: <start> ERROR!! available worker process count less than $1" >> /tmp/upload_update.log
        exit 2
    fi
}

conf_check() {
    # 检查是否有正常接收连接的worker process
    num=`${NGX_PATH} -t -p ./`
    if [ $? -ne 0 ]; then
        echo "`date`: <start> ERROR!! config error" >> /tmp/upload_update.log
        exit 3
    fi
}

upgrade() {
    # 如果还存在老的 nginx pid
    if [ -f logs/nginx.pid.oldbin -a -f logs/nginx.pid ]; then
        pid=`cat logs/nginx.pid`
        oldpid=`cat logs/nginx.pid.oldbin`

        useless_master_pid=0

        old_master_available_worker_num=`ps -eo pid,ppid,cmd | grep ${NGX_TITLE} | grep -w $oldpid | grep worker | grep -v shutting | wc -l`
        master_available_worker_num=`ps -eo pid,ppid,cmd | grep ${NGX_TITLE} | grep -w $pid | grep worker | grep -v shutting | wc -l`

        if [ $old_master_available_worker_num == 0 ]; then
            echo "`date`: <start> updating, old master($oldpid) and master($pid) both exist, old master have no available worker process, kill it and its workers" >> /tmp/upload_update.log
            useless_master_pid=$oldpid
        elif [ $master_available_worker_num == 0 ]; then
            echo "`date`: <start> updating, old master($oldpid) and master($pid) both exist, master have no available worker process, kill it and its workers" >> /tmp/upload_update.log
            useless_master_pid=$pid
        else
            # old master 不能递归
            echo "`date`: <start> WARNING!!! updating, old master($oldpid) and master($pid) both exist, both have available worker process, <start> failed, but binary file already updated" >> /tmp/upload_update.log
            # rm live_upload_updating.log
            exit 2
        fi

        # 强制杀死master 进程，有流的worker 变为孤儿进程
        kill -s QUIT $useless_master_pid
        sleep 0.5
        # 强制检查 useless_master 必须退出，退出后才能发 SIGUSR2
        num=`ps -eo pid,ppid,cmd | grep ${NGX_TITLE} | grep -w $useless_master_pid | grep master | wc -l`
        while [ $num -gt 0 ]
        do
            kill -9 $useless_master_pid
            sleep 0.5
            num=`ps -eo pid,ppid,cmd | grep ${NGX_TITLE} | grep -w $useless_master_pid | grep master | wc -l`
        done

        # 防止老的 pid文件没删除
        if [ -f logs/nginx.pid.oldbin ]; then
            rm -f logs/nginx.pid.oldbin
        fi
    fi

    # 平滑升级
    pid=`cat logs/nginx.pid`
    echo "`date`: <start> updating, send sigusr2 to master($pid), take effect new binary file" >> /tmp/upload_update.log

    kill -s USR2 $pid
    sleep 0.2

    # 检查是否有两个nginx master process（个别异常情况，SIGUSR2会被ignore），最多检查三次
    check_times=0
    while [ $check_times -lt 3 ]
    do
        num=`ps -eo pid,ppid,cmd | grep ${NGX_TITLE} | grep -w ${NGX_TITLE} | grep master | wc -l`
        if [ $num -ne 2 ]; then
            sleep 0.5
        else
            break
        fi

        ((check_times++))
    done

    if [ $check_times -eq 3 ]; then
        echo "`date`: <start> ERROR!! sigusr2 maybe be ignored, master process count is not 2" >> /tmp/upload_update.log
        exit 2
    fi

    kill -s WINCH $pid
}

NGX_ROOT="out/"
if [ $# -ge 1 ]
then
    NGX_ROOT=$1
fi

CUR_DIR=$(pwd)
cd ${NGX_ROOT}

if pgrep -f "${NGX_TITLE}: master process" > /dev/null; then
    echo "Nginx master process is already running."
    conf_check
    upgrade
else
    echo "Nginx master process is not running."
    echo "Starting Nginx..."
    conf_check
    ${NGX_PATH} -p .
fi
alive_check 1

# 提高 nginx 进程 OOM 分数，减少被kill 概率
pgrep -f ${NGX_TITLE} | while read PID;do echo -500 > /proc/$PID/oom_score_adj ; done

cd ${CUR_DIR}
