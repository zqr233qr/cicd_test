# 项目搭建记录

## 2025年12月17日 - 项目初始化
- [x] 检查 Go 环境: `go version`
- [x] 初始化 Go module: `go mod init cicd_test`
- [x] 创建基础代码 `main.go` 和测试 `main_test.go`，用于后续演示 CI 自动化测试。
- [x] 创建项目文档 `README.md` 和记录文档 `setup.md`。

## 2025年12月17日 - 配置 GitHub Actions (CI)
- [x] 创建目录 `.github/workflows`。
- [x] 编写工作流文件 `ci.yml`，包含以下步骤：
    - Checkout 代码
    - Setup Go 环境
    - Run Test (单元测试)
    - Run Build (构建检查)
- [x] 更新文档说明。

## 2025年12月17日 - 配置 Docker (CD)
- [x] 创建 `Dockerfile`，采用多阶段构建优化镜像体积。
- [x] 更新 GitHub Actions 配置，增加 Docker 构建步骤。
- [x] 验证 CI/CD 流程。

### Docker 构建问题排查与解决
- **问题 1 (首次构建失败)**: `go mod download` 失败，提示 `fatal: pathspec 'go.sum' did not match any files` 或 `无文件要提交，干净的工作区`。
    - **原因**: 初始项目无外部依赖，`go mod tidy` 未生成 `go.sum`，导致 `Dockerfile` 中 `COPY go.sum` 和 `go mod download` 步骤失败。
    - **解决方案**: 暂时移除 `Dockerfile` 中 `go mod download` 步骤，让 `go build` 自动处理。
- **问题 2 (Go Gin 框架引入后再次构建失败)**: `go mod download` 再次失败，提示 `go: go.mod requires go >= 1.24.0 (running go 1.23.12; GOTOOLCHAIN=local)`。
    - **原因**: `go.mod` 文件（因引入 Gin 依赖后）实际要求 Go 1.24.0 及以上版本，但 `Dockerfile` 中使用的 `golang:1.23-alpine` 镜像只包含 Go 1.23.12。Go 版本不匹配导致依赖下载失败。
    - **解决方案**: 将 `Dockerfile` 中的基础镜像从 `golang:1.23-alpine` 切换到 `golang:1.25`（非 Alpine 版，更稳定），并将 `go.mod` 中的 Go 版本声明也更新为 `1.25.0`。
- **问题 3 (本次操作)**: 确认 Go 版本匹配后，重新尝试使用 `golang:1.25-alpine`。
    - **原因**: 经过前两次排查，我们已经明确问题是 Go 版本不兼容，而非 Alpine 镜像本身。现在 Go 版本已匹配，可以再次尝试 Alpine 镜像以获得更小的最终镜像体积。
    - **解决方案**: 修改 `Dockerfile`，将构建阶段的基础镜像切换回 `golang:1.25-alpine`。

## 2025年12月17日 - 配置 Docker Registry (GHCR)
- [x] 更新 `ci.yml`，添加 `permissions: packages: write`。
- [x] 添加 `docker/login-action` 步骤登录 ghcr.io。
- [x] 使用 `docker/metadata-action` 自动管理镜像标签。
- [x] 启用 `push: true` 将镜像推送到 GHCR。

## 待办事项
- [ ] 将代码推送到 GitHub 仓库以触发 CI/CD。
- [ ] 在 GitHub 个人主页的 Packages 标签页查看推送成功的镜像。
