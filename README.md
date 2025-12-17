# CICD 学习项目

这是一个用于学习 CI/CD (持续集成/持续部署) 的示例 Go 项目。

## 当前状态
- 已初始化简单的 Go 程序和单元测试。

## 项目结构
- `main.go`: 简单的 Go 应用程序
- `main_test.go`: 单元测试

## 常用命令
- 运行代码: `go run main.go`
- 运行测试: `go test -v ./...`

## CI/CD 状态
本项目使用 GitHub Actions 进行持续集成。
- 配置文件: `.github/workflows/ci.yml`
- 触发条件: Push 或 Pull Request 到 `main` 分支
- 执行内容: 代码检查、测试、构建

## 持续部署 (CD)
- Docker 镜像会自动构建并推送到 GitHub Container Registry (GHCR)。
- 部署脚本已集成到 GitHub Actions，通过 SSH 连接到目标服务器进行自动部署。
  - 配置文件: `.github/workflows/ci.yml` 中的 `deploy` 任务。
  - Secrets 配置: 需在 GitHub 仓库中配置 `SERVER_HOST`, `SERVER_USER`, `SERVER_SSH_KEY`。
