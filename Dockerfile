# 第一阶段：构建阶段
FROM golang:1.23-alpine AS builder

# 设置工作目录
WORKDIR /app

# 复制 go.mod 和 go.sum (如果有)
# COPY go.mod go.sum ./
# RUN go mod download

# 复制源代码
COPY . .

# 编译应用
# CGO_ENABLED=0 禁用 CGO，确保生成静态链接的可执行文件
# -o main 指定输出文件名为 main
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

# 第二阶段：运行阶段
FROM alpine:latest

# 设置工作目录
WORKDIR /root/

# 从构建阶段复制编译好的可执行文件
COPY --from=builder /app/main .

# 暴露端口 (虽然我们的简单示例还没用到端口，但这是标准做法)
# EXPOSE 8080

# 运行应用
CMD ["./main"]
