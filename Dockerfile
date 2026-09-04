FROM swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/eclipse-temurin:21-jre
LABEL author="神人"
LABEL email="zxcvbnm1916716@qq.com"
# 复制全部项目文件到容器 /mc
COPY . /mc
# 设置上海时区
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo 'Asia/Shanghai' >/etc/timezone
# 工作目录
WORKDIR /mc
# 清理无用文件，减小镜像
RUN rm -rf backups .SystemConfig Dockerfile
# 给启动脚本执行权限
RUN chmod +x mc.sh
# 开放端口：Java版、Geyser基岩UDP、MCSSH控制台
EXPOSE 29366/tcp
EXPOSE 19132/udp
EXPOSE 14444/tcp
# 容器入口脚本
CMD ["/mc/mc.sh"]
