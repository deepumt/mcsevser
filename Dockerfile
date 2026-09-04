FROM eclipse-temurin:21-jre
LABEL author="神人"
LABEL email="zxcvbnm1916716@qq.com"
# 复制全部项目文件到容器 /mc
COPY . /mc
# 工作目录
WORKDIR /mc
# 给启动脚本执行权限
RUN chmod +x mc.sh
# 开放端口：Java版、Geyser基岩UDP、MCSSH控制台
EXPOSE 29366/tcp
EXPOSE 19132/udp
EXPOSE 14444/tcp
# 容器入口脚本
CMD ["/mc/mc.sh"]
RUN rm -rf .git .gitee .github Dockerfile
