# Registry · 镜像仓库

本地 SRE Lab 的容器镜像仓库，基于官方 `registry:2`。

## 部署位置

| 项 | 值 |
| --- | --- |
| Namespace | `infra` |
| 镜像 | `registry:2` |
| Service | `registry.infrastructure.svc.cluster.local:5000` (ClusterIP) |
| Ingress | `/registry` → `registry:5000` |
| 访问 | `http://localhost:30080/registry/` |

## 文件

```text
registry/
├── namespace.yaml    # infra
├── deployment.yaml   # registry:2, 5000, emptyDir 存储
├── service.yaml      # ClusterIP 5000
├── ingress.yaml      # /registry
├── install.sh
├── uninstall.sh
└── README.md
```

## 安装 / 卸载

```bash
cd registry && chmod +x install.sh uninstall.sh
./install.sh
./uninstall.sh
```

## 使用

```bash
# 打标签并推送到本地仓库（需先 docker login 或配置 insecure registry）
docker tag myapp:latest localhost:30080/registry/myapp:latest
docker push localhost:30080/registry/myapp:latest
```

## 说明 Notes

- 当前用 `emptyDir` 存储，**重启 Pod 镜像丢失**；生产应换 PVC 或对象存储（S3/MinIO），并加 TLS 与认证（建议 Harbor）。
- 镜像仓库与首页 `registry` 卡片联动：部署后首页 `/registry` 卡片即可点击。
- Docker Desktop 推送 `localhost:30080/registry` 需在 Docker 配置中将 `localhost:30080` 设为 insecure registry。
