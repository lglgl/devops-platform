#!/bin/bash

# Jenkins Port Forward 管理脚本
# Namespace: cicd
# Service: jenkins
# 本地端口: 18080

PID_FILE="$HOME/logs/jenkins-port-forward.pid"
LOG_FILE="$HOME/logs/jenkins-port-forward.log"
LOCAL_PORT=18080
NAMESPACE="cicd"
SERVICE="jenkins"

mkdir -p "$HOME/logs"

# 检查 PID 对应的进程是否仍在运行
is_running() {
    if [[ -f "$PID_FILE" ]]; then
        PID=$(cat "$PID_FILE")
        if [[ "$PID" =~ ^[0-9]+$ ]] && kill -0 "$PID" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

start() {
    if is_running; then
        PID=$(cat "$PID_FILE")
        echo "Jenkins Port Forward 已运行，PID: $PID"
        return 0
    fi

    rm -f "$PID_FILE"

    # 检查本地端口是否已被占用
    if lsof -nP -iTCP:"$LOCAL_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
        echo "错误：本地端口 $LOCAL_PORT 已被占用"
        lsof -nP -iTCP:"$LOCAL_PORT" -sTCP:LISTEN
        echo "请先释放端口，或修改 LOCAL_PORT"
        return 1
    fi

    # 检查 Jenkins Pod 是否运行
    if ! kubectl get pods -n "$NAMESPACE" \
        -l app.kubernetes.io/instance=jenkins \
        --no-headers 2>/dev/null | grep -q "Running"; then
        echo "警告：未检测到 Running 状态的 Jenkins Pod"
        echo "请执行 kubectl get pods -n $NAMESPACE 检查"
        return 1
    fi

    # 后台启动端口转发
    nohup kubectl port-forward \
        -n "$NAMESPACE" "svc/$SERVICE" \
        "${LOCAL_PORT}:8080" \
        > "$LOG_FILE" 2>&1 < /dev/null &

    PID=$!
    echo "$PID" > "$PID_FILE"

    sleep 2

    # 验证进程及监听端口
    if kill -0 "$PID" 2>/dev/null && \
       lsof -nP -iTCP:"$LOCAL_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
        echo "Jenkins Port Forward 启动成功"
        echo "PID: $PID"
        echo "访问地址: http://localhost:${LOCAL_PORT}/"
        echo "日志文件: $LOG_FILE"
    else
        echo "启动失败，请检查日志："
        cat "$LOG_FILE"
        rm -f "$PID_FILE"
        return 1
    fi
}

stop() {
    if is_running; then
        PID=$(cat "$PID_FILE")
        kill "$PID" 2>/dev/null
        sleep 1
        rm -f "$PID_FILE"
        echo "已发送停止信号，PID: $PID"
    else
        echo "Jenkins Port Forward 未运行"
        rm -f "$PID_FILE"
    fi
}

status() {
    if is_running; then
        PID=$(cat "$PID_FILE")
        echo "Jenkins Port Forward 进程运行中，PID: $PID"
        ps -p "$PID" -o pid,etime,command
        echo ""
        lsof -nP -iTCP:"$LOCAL_PORT" -sTCP:LISTEN
    else
        echo "Jenkins Port Forward 未运行"
    fi
}

logs() {
    if [[ -f "$LOG_FILE" ]]; then
        tail -f "$LOG_FILE"
    else
        echo "日志文件不存在：$LOG_FILE"
    fi
}

case "$1" in
    start)   start ;;
    stop)    stop ;;
    restart) stop; sleep 1; start ;;
    status)  status ;;
    logs)    logs ;;
    *)
        echo "用法: $0 {start|stop|restart|status|logs}"
        exit 1
        ;;
esac
