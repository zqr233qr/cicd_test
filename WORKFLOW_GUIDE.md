# GitHub Actions 配置文件详解 (`.github/workflows/ci.yml`)

这份文档逐行解析了本项目使用的 CI/CD 配置文件，帮助你理解每一行代码背后的含义和作用。

## 1. 核心概念速查

- **Workflow (工作流)**: 整个自动化流程的统称（即这个 `.yml` 文件）。
- **Job (任务)**: 工作流中包含的一组步骤（Step）。Jobs 默认是**并行**运行的，除非使用了 `needs` 指定依赖关系。
- **Step (步骤)**: 任务中最小的执行单元，可以是运行 Shell 命令，也可以是使用现成的插件 (Action)。
- **Action (插件)**: `uses: ...` 引用的就是别人写好的封装代码，比如拉取代码、登录 Docker 等。
- **Runner (运行器)**: `runs-on: ubuntu-latest` 指定了 GitHub 分配给我们的虚拟服务器环境。
- **Secrets (密钥)**: `${{ secrets.XXX }}` 用于引用你在 GitHub 仓库设置中配置的敏感信息（密码、私钥）。

---

## 2. 配置文件结构解析

### 头部定义：名字与触发器

```yaml
name: Go CI  # 工作流在 GitHub Actions 页面显示的名称

on:          # 触发条件：什么时候运行这个工作流？
  push:      # 当发生 Push 事件时
    branches: [ "main" ] # 只有推送到 main 分支时触发
    tags: [ "v*" ]       # 或者推送了以 v 开头的标签 (如 v1.0.0) 时触发
  pull_request: # 当发生 Pull Request (合并请求) 时
    branches: [ "main" ] # 只有目标是 main 分支的 PR 才触发
```

### 任务一：构建与测试 (CI 核心)

这是最基础的任务，用于保证代码质量。

```yaml
jobs:
  build-and-test:
    name: Build and Test
    runs-on: ubuntu-latest # 使用最新的 Ubuntu 虚拟环境
    
    steps:
    # uses: 引用官方插件。actions/checkout 用于把你的代码下载到虚拟环境里。
    - name: Checkout code
      uses: actions/checkout@v4

    # actions/setup-go 用于安装指定版本的 Go 环境。
    - name: Set up Go
      uses: actions/setup-go@v5
      with:
        go-version: '1.23' # 指定 Go 版本
        check-latest: true

    # run: 执行普通的 Shell 命令。
    - name: Get dependencies
      run: go mod download # 下载 Go 依赖

    - name: Test
      run: go test -v ./... # 运行所有单元测试

    - name: Build
      run: go build -v ./... # 尝试编译代码，确保没有语法错误
```

### 任务二：构建 Docker 镜像 (CD - Build)

这个任务负责打包应用。它依赖于测试任务的成功。

```yaml
  docker-build:
    name: Build Docker Image
    needs: build-and-test # [关键依赖]: 只有 build-and-test 成功了，才会运行这个任务
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write # [权限设置]: 授予此任务向 GitHub Packages 推送镜像的权限

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      # Docker 构建工具链设置
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      # [登录镜像仓库]: 使用 GitHub 的临时 Token 登录 ghcr.io
      - name: Log in to the Container registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }} # 触发工作流的用户名
          password: ${{ secrets.GITHUB_TOKEN }} # GitHub 自动生成的临时密码

      # [自动生成标签]: 这是最复杂也最强大的部分
      # 它会根据触发事件（分支推送还是标签推送）自动决定镜像叫什么
      - name: Extract metadata (tags, labels) for Docker
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            # 如果是打标签触发 (v1.0.0)，则生成镜像标签 :1.0.0
            type=semver,pattern={{version}}
            # 同时生成镜像标签 :1.0
            type=semver,pattern={{major}}.{{minor}}
            # 如果是 main 分支触发，则生成 :latest 标签
            type=raw,value=latest,enable=${{ github.ref == format('refs/heads/{0}', 'main') }}

      # [构建并推送]: 真正执行 docker build 和 docker push 的地方
      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile
          push: true # 推送到仓库
          tags: ${{ steps.meta.outputs.tags }} # 使用上面 meta 步骤生成的标签
          labels: ${{ steps.meta.outputs.labels }}
```

### 任务三：发布版本 (Release Management)

用于在 GitHub 上创建 Release 页面。

```yaml
  create-release:
    name: Create GitHub Release
    needs: [build-and-test, docker-build] # 等待测试和镜像构建都完成
    runs-on: ubuntu-latest
    if: startsWith(github.ref, 'refs/tags/v') # [条件判断]: 只有推送标签 (v...) 时才运行
    permissions:
      contents: write # 需要写权限来创建 Release

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      # 自动创建 Release 并生成更新日志
      - name: Create Release
        uses: softprops/action-gh-release@v2
        with:
          generate_release_notes: true
```

### 任务四：部署到服务器 (CD - Deploy)

用于将新镜像发布到你的云服务器。

```yaml
  deploy:
    name: Deploy to Server
    needs: docker-build # 等待镜像构建完成
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' # 仅 main 分支触发部署（开发环境通常如此）
    
    steps:
      # appleboy/ssh-action 是一个通过 SSH 远程执行命令的插件
      - name: Deploy using SSH
        uses: appleboy/ssh-action@v1.0.3
        env:
          IMAGE_TAG: ghcr.io/${{ github.repository }}:main # 定义环境变量
        with:
          host: ${{ secrets.SERVER_HOST }}     # 从 Secrets 读取服务器 IP
          username: ${{ secrets.SERVER_USER }} # 从 Secrets 读取用户名
          key: ${{ secrets.SERVER_SSH_KEY }}   # 从 Secrets 读取私钥
          envs: IMAGE_TAG # 将上面的环境变量传递给远程脚本
          script: |
            # 以下命令在你的云服务器上执行：
            echo "Deploying $IMAGE_TAG..."
            docker pull $IMAGE_TAG      # 1. 拉取新镜像
            docker stop cicd-app || true # 2. 停止旧容器 (忽略不存在的错误)
            docker rm cicd-app || true   # 3. 删除旧容器
            # 4. 启动新容器
            docker run -d --name cicd-app --restart unless-stopped -p 8080:8080 $IMAGE_TAG
```

## 3. 常见变量说明

| 变量 | 说明 | 示例 |
| :--- | :--- | :--- |
| `${{ github.repository }}` | 仓库名称 (用户名/仓库名) | `zqr233qr/cicd_test` |
| `${{ github.ref }}` | 触发引用的全名 | `refs/heads/main` 或 `refs/tags/v1.0.0` |
| `${{ github.actor }}` | 触发者的用户名 | `zqr233qr` |
| `${{ secrets.GITHUB_TOKEN }}` | GitHub 自动生成的权限令牌 | (自动生成，用于鉴权) |
| `${{ steps.meta.outputs.tags }}` | 引用 id 为 `meta` 的步骤的输出 | `ghcr.io/...:latest` |

---

## 4. 进阶问答 (FAQ)

### Q1: 配置文件的命名和数量有限制吗？
*   **文件名**：没有限制，只要以 `.yml` 或 `.yaml` 结尾即可。
*   **位置**：必须位于 `.github/workflows/` 目录下。
*   **数量**：可以有多个配置文件（多个 Workflow）。它们相互独立，互不影响。如果多个 Workflow 的触发条件相同，它们会**并行运行**。
*   **Name**：每个文件内的 `name` 字段是该 Workflow 的显示名称。

### Q2: 同时推送代码和标签 (Branch & Tag) 会触发两次吗？
*   **是的**。如果你执行 `git push --atomic origin main v1.0.0`，GitHub Actions 通常会触发两次：
    1.  一次由 `branches: ["main"]` 触发（代码更新）。
    2.  一次由 `tags: ["v*"]` 触发（标签更新）。
*   **处理建议**：在 Workflow 内部使用 `if` 条件（如 `if: startsWith(github.ref, 'refs/tags/')`）来区分不同触发源，执行不同的任务（例如 Tag 触发才进行 Release）。

### Q3: `pull_request` 是在合并时触发吗？
*   **不是**。`on: pull_request` 默认是在 **发起 PR** 或 **PR 内有新提交** 时触发。
*   **目的**：用于在代码合并前进行检查（CI），确保新代码不会破坏现有功能。
*   **合并时**：当 PR 被合并后，会触发目标分支（如 `main`）的 `on: push` 事件。

### Q4: Jobs 的名称（如 `build-and-test`）是固定的吗？
*   **不是**。这是自定义的 ID（标识符），你可以随意命名（只允许字母、数字、`-`、`_`）。
*   **作用**：用于在 `needs: [...]` 中声明依赖关系，以及在 GitHub 界面上显示。

### Q5: `runs-on: ubuntu-latest` 是谁提供的？权限 `contents` 指什么？
*   **运行环境**：由 GitHub 官方免费提供的 Azure 虚拟机（GitHub Hosted Runners）。公开仓库免费无限制，私有仓库有每月额度限制。
*   **权限 (`permissions`)**：
    *   **GITHUB_TOKEN**：GitHub 自动注入的鉴权令牌。
    *   **contents**: 控制对代码仓库的读写权限（`read`: 拉取代码; `write`: 提交代码/创建 Release）。
    *   **packages**: 控制对 GitHub Packages (GHCR) 的上传权限。

### Q6: 常用官方插件的作用是什么？
*   **`actions/checkout`**: 相当于 `git clone`，将代码下载到运行环境。
*   **`actions/setup-go`**: 安装配置 Go 语言环境。
*   **`docker/setup-buildx-action`**: 安装 Docker Buildx 构建工具，支持高级构建特性。
*   **`docker/login-action`**: 登录镜像仓库 (docker login)。
*   **`docker/metadata-action`**: **神级插件**。自动根据 Git 分支/标签生成 Docker 镜像的 Tag（如自动处理 `latest`, `1.0.0`）。
*   **`docker/build-push-action`**: 执行 Docker 构建和推送。
*   **`appleboy/ssh-action`**: (非官方但流行) 通过 SSH 连接远程服务器执行部署脚本。

### Q7: 真实开发中的测试依赖本地环境（如 DB），CI 跑不通怎么办？
这是一个非常常见的问题。可以采用以下几种策略：

1.  **跳过测试 (Skip)**: 在 Go 测试代码中检查 `CI` 环境变量。
    ```go
    if os.Getenv("CI") != "" { t.Skip("Skipping in CI") }
    ```
2.  **补齐环境 (Services)**: 在 `.yml` 中使用 `services` 关键字启动 MySQL/Redis 容器，让 CI 环境拥有和开发环境一样的数据库。
3.  **允许失败**: 给测试步骤添加 `continue-on-error: true`，虽然测试红了，但不会阻断构建和发布（慎用）。
4. **Mock (推荐)**: 优化代码，使用接口和 Mock 技术将外部依赖剥离，编写纯粹的单元测试。

---

## 5. 附录：企业级 GitLab CI/CD 迁移指南

在企业内部开发中，GitLab CI/CD 是主流选择。如果你掌握了 GitHub Actions，迁移到 GitLab CI 只需要适应其“方言”。

### 核心思维差异

| 特性 | GitHub Actions | GitLab CI/CD |
| :--- | :--- | :--- |
| **配置文件** | `.github/workflows/*.yml` | 根目录 `.gitlab-ci.yml` |
| **执行环境** | `runs-on` + `uses: setup-xxx` (插件安装环境) | **`image: xxx`** (直接在 Docker 容器内运行) |
| **流程控制** | `needs: [job-a]` (依赖图) | `stages: [build, test, deploy]` (线性阶段) |
| **Docker构建**| 使用 `setup-buildx` 插件 | 使用 **Docker-in-Docker (dind)** 服务 |

### 翻译对照表 (.gitlab-ci.yml 示例)

```yaml
# 1. 定义执行顺序 (Stage)
stages:
  - test
  - build
  - deploy

# 2. 测试阶段 (对应 build-and-test)
test_job:
  stage: test
  image: golang:1.25-alpine # 直接使用 Go 镜像
  script:
    - go test -v ./...

# 3. 构建阶段 (对应 docker-build)
build_image:
  stage: build
  image: docker:latest
  services:
    - docker:dind # 启用 Docker 守护进程
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA

# 4. 部署阶段 (对应 deploy)
deploy_prod:
  stage: deploy
  image: alpine:latest
  before_script:
    - apk add openssh-client # 安装 SSH 工具
    # ... 配置 SSH Key ...
  script:
    - ssh user@host "docker pull ... && docker run ..."
  only:
    - main
```

