# Nexus 私服搭建与运维实战手册

本手册旨在指导运维/开发团队快速搭建 Sonatype Nexus Repository OSS（免费版），并建立配套的权限管理体系与 CI/CD 安全扫描流程。

**文档目录**

1.  [服务搭建 (Server Setup)](#一-nexus-服务搭建-docker-方式)
2.  [仓库配置 (Repository Setup)](#二-仓库配置-repository-setup)
3.  [权限管理 (RBAC)](#三-权限管理-rbac)
4.  [客户端接入 (Client Configuration)](#四-客户端配置指南)
5.  [CI/CD 扫描实战 (SCA)](#五-cicd-流水线扫描与合规实战-sca-方案)
6.  [运维维护 (Maintenance)](#六-运维维护)
7.  [附录：接入资源 (Onboarding)](#七-附录接入资源-onboarding)

---

## 一、 Nexus 服务搭建 (Docker 方式)

推荐使用 Docker 容器化部署，维护成本最低。

### 1.1 环境准备
*   **OS**: Linux (CentOS 7+/Ubuntu 20.04+) 或 Windows Server
*   **Docker**: 需已安装 Docker Engine (推荐版本 20.10+)
*   **硬件**: 建议 4核 8G 内存，磁盘 200G+ (SSD 推荐，取决于依赖包数量)
*   **网络**: 服务器需具备访问公网权限（用于同步中央仓库），需开放 8081 端口。

### 1.2 部署与启动
1.  **创建数据目录**（用于持久化存储数据，防止容器删除后数据丢失）：
    ```bash
    # 创建目录并设置权限 (UID 200 是 nexus 容器内用户的 ID)
    mkdir -p /data/nexus-data && chown -R 200:200 /data/nexus-data
    ```

2.  **启动 Nexus 3 容器**：
    ```bash
    docker run -d \
      -p 8081:8081 \
      --name nexus \
      -v /data/nexus-data:/nexus-data \
      --restart always \
      -e "INSTALL4J_ADD_VM_PARAMS=-Xms2g -Xmx4g -XX:MaxDirectMemorySize=2g" \
      sonatype/nexus3
    ```
    *   *注：`-e` 参数用于调整 JVM 内存，避免 OOM。*

3.  **验证服务状态**：
    ```bash
    docker logs -f nexus
    # 等待出现 "Started Sonatype Nexus OSS ..." 字样，通常需 2-5 分钟
    ```

### 1.3 初始化配置
1.  **访问 Web 界面**: 浏览器打开 `http://<服务器IP>:8081`
2.  **获取初始管理员密码**:
    ```bash
    docker exec nexus cat /nexus-data/admin.password
    ```
3.  **首次登录向导**:
    *   点击右上角 "Sign in"，用户 `admin`，密码为上一步获取的字符串。
    *   **Update Password**: 设置强密码（如 `Admin@Company2024`）。
    *   **Anonymous Access**: 建议选择 **Disable**（禁用匿名访问），强制所有客户端认证，便于审计。

---

## 二、 仓库配置 (Repository Setup)

Nexus 将仓库分为三种类型，建议严格按照标准命名规范创建：

### 2.1 仓库类型说明
*   **Proxy (代理仓库)**: 
    *   用途：连接外网中央仓库 (如 Maven Central, npmjs)。
    *   机制：本地没有 -> 去外网下 -> 缓存到本地 -> 返回给用户。
*   **Hosted (宿主仓库)**: 
    *   用途：存放公司内部私有包、第三方无法下载的商业包 (如 Oracle JDBC)。
    *   策略：分为 `Releases` (正式版，不可覆盖) 和 `Snapshots` (快照版，可频繁覆盖)。
*   **Group (仓库组)**: 
    *   用途：虚拟仓库，聚合 Proxy 和 Hosted。
    *   配置：客户端只需配置 Group 地址，即可同时拉取内网和外网包。

### 2.2 实战：创建 Maven 仓库体系
1.  **创建 Proxy 仓库 (代理阿里云)**
    *   路径：`Settings` -> `Repositories` -> `Create repository` -> `maven2 (proxy)`
    *   Name: `maven-aliyun`
    *   Remote storage: `https://maven.aliyun.com/repository/public`
    *   Blob store: `default`
    *   点击 `Create repository`。

2.  **创建 Hosted 仓库 (内部发行版)**
    *   路径：`Create repository` -> `maven2 (hosted)`
    *   Name: `maven-releases`
    *   Version policy: `Release`
    *   Deployment policy: **Disable redeploy** (严禁覆盖正式版本，确保构建可追溯)

3.  **创建 Hosted 仓库 (内部快照版)**
    *   路径：`Create repository` -> `maven2 (hosted)`
    *   Name: `maven-snapshots`
    *   Version policy: `Snapshot`
    *   Deployment policy: **Allow redeploy**

4.  **创建 Group 仓库 (对外统一入口)**
    *   路径：`Create repository` -> `maven2 (group)`
    *   Name: `maven-public`
    *   Member repositories: 将 `maven-releases`, `maven-snapshots`, `maven-aliyun` 依次移入右侧 Members 列表。
    *   *注意顺序：内部库在前，代理库在后。*

### 2.3 实战：创建 npm 仓库体系
1.  **npm Proxy**: 
    *   Type: `npm (proxy)`
    *   Name: `npm-proxy`
    *   Remote storage: `https://registry.npmmirror.com`
2.  **npm Hosted**: 
    *   Type: `npm (hosted)`
    *   Name: `npm-private`
    *   Deployment policy: `Allow redeploy` (npm 通常允许覆盖，视团队规范而定)
3.  **npm Group**: 
    *   Type: `npm (group)`
    *   Name: `npm-group`
    *   Members: `npm-private` -> `npm-proxy`

---

## 三、 权限管理 (RBAC)

目标：遵循**最小权限原则**，分离开发人员与 CI 机器人的权限。

### 3.1 创建角色 (Roles)
进入 **Settings -> Security -> Roles -> Create role**。

#### 角色 A: `nx-developer` (普通开发 - 仅下载)
*   **Role ID**: `nx-developer`
*   **Privileges**: 搜索并添加以下权限：
    *   `nx-repository-view-*-*-read` (读取所有仓库内容)
    *   `nx-repository-view-*-*-browse` (浏览所有仓库目录)
*   *安全提示：切勿给予 `edit` 或 `delete` 权限，防止开发人员误删包。*

#### 角色 B: `nx-deployer` (发布者 - 用于 CI/CD)
*   **Role ID**: `nx-deployer`
*   **Privileges**:
    *   `nx-repository-view-maven2-maven-releases-add` (允许向 maven-releases 上传)
    *   `nx-repository-view-maven2-maven-releases-edit`
    *   `nx-repository-view-maven2-maven-snapshots-*`
    *   `nx-repository-view-npm-npm-private-add`
    *   `nx-repository-view-npm-npm-private-edit`
*   *注意：通常不允许 delete 权限，删除操作应由管理员执行。*

### 3.2 创建用户 (Users)
进入 **Settings -> Security -> Users**。

1.  **User**: `dev-user`
    *   First Name: Developer
    *   Email: dev@company.com
    *   Status: Active
    *   Roles: `nx-developer`
    *   *用途：分发给所有开发人员配置本地环境，只读权限。*

2.  **User**: `ci-bot`
    *   First Name: CI Robot
    *   Roles: `nx-deployer`
    *   *用途：配置在 Jenkins/GitLab CI 变量中，用于自动发布。*

---

## 四、 客户端配置指南

### 4.1 Maven (Java)
**配置文件路径**: 
*   用户级 (推荐): `~/.m2/settings.xml` (Windows: `%USERPROFILE%\.m2\settings.xml`)

**配置示例**:
```xml
<settings>
  <servers>
    <!-- 认证信息：id 必须与 pom.xml 中 distributionManagement 的 id 匹配 -->
    <server>
      <id>nexus-releases</id>
      <username>dev-user</username>
      <password>DevPassword123</password>
    </server>
    <server>
      <id>nexus-snapshots</id>
      <username>dev-user</username>
      <password>DevPassword123</password>
    </server>
  </servers>
  
  <mirrors>
    <!-- 镜像拦截：强制所有请求（包括 central）走私服 -->
    <mirror>
      <id>nexus</id>
      <mirrorOf>*</mirrorOf>
      <url>http://<私服IP>:8081/repository/maven-public/</url>
    </mirror>
  </mirrors>
  
  <profiles>
    <profile>
      <id>nexus</id>
      <repositories>
        <repository>
          <id>central</id>
          <url>http://central</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </repository>
      </repositories>
      <pluginRepositories>
        <pluginRepository>
          <id>central</id>
          <url>http://central</url>
          <releases><enabled>true</enabled></releases>
          <snapshots><enabled>true</enabled></snapshots>
        </pluginRepository>
      </pluginRepositories>
    </profile>
  </profiles>
  
  <activeProfiles>
    <activeProfile>nexus</activeProfile>
  </activeProfiles>
</settings>
```

### 4.2 npm (Node.js)
**配置文件路径**: 项目根目录 `.npmrc` (推荐) 或 用户主目录 `~/.npmrc`。

**配置命令**:
```bash
# 1. 设置 registry 指向 Group 仓库
npm config set registry http://<私服IP>:8081/repository/npm-group/

# 2. 登录获取 Token (输入 dev-user / 密码 / 邮箱)
npm login --registry=http://<私服IP>:8081/repository/npm-group/
# 登录成功后，Token 会自动写入 ~/.npmrc
```

**验证配置**:
```bash
npm config list
npm install react --verbose # 查看请求地址是否为私服 IP
```

### 4.3 Python (PyPI)
**配置文件路径**:
*   Windows: `%APPDATA%\pip\pip.ini`
*   Linux/macOS: `~/.pip/pip.conf`

**配置内容**:
```ini
[global]
index-url = http://<私服IP>:8081/repository/pypi-group/simple
trusted-host = <私服IP>
timeout = 120

[search]
index = http://<私服IP>:8081/repository/pypi-group/pypi
```

### 4.4 Docker
**配置文件路径**: `/etc/docker/daemon.json` (Linux) 或 Docker Desktop -> Docker Engine。

**配置内容**:
```json
{
  "insecure-registries": ["<私服IP>:8082"],
  "registry-mirrors": ["http://<私服IP>:8082"]
}
```
*注：需在 Nexus 中创建一个 Docker Group 仓库，并为其绑定 HTTP 端口 (如 8082)。*

### 4.5 Go Modules
**环境变量配置**:
```bash
# 设置 GOPROXY 指向 Nexus
export GOPROXY=http://<私服IP>:8081/repository/go-group/
# 设置私有库前缀不走代理
export GONOSUMDB=github.com/mycompany/*
```

---

## 五、 CI/CD 流水线扫描与合规实战 (SCA 方案)

本章节详细介绍如何在**不购买商业版 Nexus Firewall** 的前提下，利用开源工具链实现**软件成分分析 (SCA)**。

### 5.1 工具选型推荐

| 语言/场景 | 推荐工具 | 扫描类型 | 优势 |
| :--- | :--- | :--- | :--- |
| **Java** | [OWASP Dependency-Check](https://owasp.org/www-project-dependency-check/) | 漏洞 (CVE) | 权威漏洞库，Maven 插件集成方便 |
| **Node.js** | [license-checker](https://www.npmjs.com/package/license-checker) | 协议 (License) | 轻量级，精准识别开源协议 |
| **Node.js** | `npm audit` | 漏洞 | 官方原生自带，无需安装额外工具 |
| **Python** | [pip-audit](https://pypi.org/project/pip-audit/) | 漏洞 | PyPA 官方维护，支持 requirements.txt |
| **Docker** | [Trivy](https://github.com/aquasecurity/trivy) | 漏洞 + 系统 | 速度极快，同时扫描 OS 层和应用层依赖 |

### 5.2 详细配置指南

#### 5.2.1 Java (Maven) - 深度漏洞扫描
在 `pom.xml` 中集成 OWASP 插件，设定“高危漏洞自动阻断”策略。

```xml
<build>
    <plugins>
        <plugin>
            <groupId>org.owasp</groupId>
            <artifactId>dependency-check-maven</artifactId>
            <version>8.2.1</version>
            <configuration>
                <!-- 自动更新漏洞库 -->
                <autoUpdate>true</autoUpdate>
                <!-- 阻断策略：CVSS 评分 >= 7.0 (高危) 时构建失败 -->
                <failBuildOnCVSS>7.0</failBuildOnCVSS>
                <!-- 生成 HTML 和 JSON 报告 -->
                <format>ALL</format>
            </configuration>
            <executions>
                <execution>
                    <goals>
                        <goal>check</goal>
                    </goals>
                </execution>
            </executions>
        </plugin>
    </plugins>
</build>
```
**执行命令**: `mvn verify`

#### 5.2.2 Node.js - 协议与漏洞双重检查
在 `package.json` 中添加以下 scripts：

```json
{
  "scripts": {
    "scan:license": "license-checker --summary --failOn 'GPL;AGPL;LGPL;MPL'",
    "scan:vuln": "npm audit --audit-level=high",
    "scan:all": "npm run scan:license && npm run scan:vuln"
  }
}
```

#### 5.2.3 Docker 容器扫描 (Trivy)
```bash
# 扫描镜像，发现高危漏洞返回非 0 状态码
trivy image --exit-code 1 --severity HIGH,CRITICAL my-app:latest
```

### 5.3 流水线集成示例 (Pipeline as Code)

#### 场景 1: GitLab CI (`.gitlab-ci.yml`)
```yaml
stages:
  - build
  - security_scan

# Java 项目扫描
dependency_check:
  stage: security_scan
  image: maven:3.8-jdk-11
  script:
    - mvn dependency-check:check
  artifacts:
    paths:
      - target/dependency-check-report.html
    expire_in: 1 week
  allow_failure: true # 初期建议允许失败，仅做记录

# Docker 镜像扫描
container_scanning:
  stage: security_scan
  image: 
    name: aquasec/trivy:latest
    entrypoint: [""]
  script:
    - trivy image --exit-code 1 --severity CRITICAL $CI_REGISTRY_IMAGE:$CI_COMMIT_TAG
```

---

## 六、 运维维护

### 6.1 磁盘清理策略 (Cleanup Policies)
Nexus 会无限缓存下载过的包，必须配置清理策略防止磁盘爆满。

1.  **创建策略**:
    *   路径：`Settings` -> `Repository` -> `Cleanup Policies` -> `Create cleanup policy`
    *   Name: `cleanup-unused-90days`
    *   Format: `All formats`
    *   **Criteria**:
        *   Last downloaded before: **90 days** (90天没被下载过的)
        *   OR Last updated before: **90 days**
2.  **应用策略**:
    *   编辑具体的仓库 (如 `maven-aliyun`, `npm-proxy`)。
    *   在 `Storage` -> `Cleanup policy` 下拉框选择 `cleanup-unused-90days`。
    *   保存。

### 6.2 数据备份
1.  **核心数据**: `/nexus-data` 目录。
2.  **备份任务**:
    *   路径：`Settings` -> `System` -> `Tasks` -> `Create task`
    *   Type: `Admin - Export configuration & metadata for backup`
    *   Schedule: `Daily` @ 02:00 AM

---

## 七、 附录：接入资源 (Onboarding)

为了让开发人员快速接入，建议运维团队准备以下资源：

1.  **公共只读账号**:
    *   Username: `dev-reader`
    *   Password: `PublicReadPassword!`
    *   *用途：所有开发人员本地拉取依赖使用，避免频繁申请账号。*

2.  **配置文件模板库**:
    *   在公司内部 Gitlab 创建 `devops-config` 仓库。
    *   存放标准的 `settings.xml`, `pip.ini`, `.npmrc` 模板文件。

3.  **一键配置脚本 (Auto-Config Script)**:
    *   创建 `setup_nexus.bat` (Windows) 供开发人员运行：

```batch
@echo off
echo Setting up Nexus Configuration...

REM 1. 配置 npm
call npm config set registry http://192.168.1.100:8081/repository/npm-group/
echo npm registry set.

REM 2. 配置 Maven (复制 settings.xml)
if not exist "%USERPROFILE%\.m2" mkdir "%USERPROFILE%\.m2"
copy /Y "\\share\devops\settings.xml" "%USERPROFILE%\.m2\settings.xml"
echo Maven settings updated.

echo Done!
pause
```
