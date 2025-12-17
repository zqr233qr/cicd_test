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
