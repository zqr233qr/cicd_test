# 第一阶段：构建阶段
# 使用 Alpine 版本镜像以优化体积
FROM golang:1.25-alpine AS builder

# 设置工作目录
WORKDIR /app

# 设置 GOPROXY 确保下载顺利
ENV GOPROXY=https://proxy.golang.org,direct

# 复制 go.mod 和 go.sum (如果有) 并下载依赖
COPY go.mod go.sum ./
RUN go mod download

# 复制源代码
COPY . .

# 编译应用
# CGO_ENABLED=0 仍然很重要，因为我们需要静态链接二进制文件以在 alpine 中运行
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

# 第二阶段：运行阶段
FROM alpine:latest

# 设置工作目录
WORKDIR /root/

# 从构建阶段复制编译好的可执行文件
COPY --from=builder /app/main .

# 暴露端口
EXPOSE 8080

# 运行应用
CMD ["./main"]
