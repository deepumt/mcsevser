#!/bin/bash
openjdk21="/opt/java/openjdk/bin/java"

while true; do
    echo "========== MC服务器启动 =========="
    "${openjdk21}" \
    -server \
    -XX:+UseG1GC \
    -XX:G1HeapRegionSize=4M \
    -Dfile.encoding=UTF-8 \
    -Duser.language=zh \
    -Dlog4j2.configurationFile=log4j2stdout.xml \
    -Duser.country=CN \
    -jar paper.jar nogui
    # 到这里代表jar进程已经结束
    echo "!!!!!!!!!! MC进程已退出，准备重启 !!!!!!!!!!"
    sleep 2
done
