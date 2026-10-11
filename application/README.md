# Application · 业务应用示例

本地 SRE Lab 的业务应用占位（当前为 `nginx:alpine` 示例），用于验证端到端链路：
CI( Jenkins ) → 镜像仓库( Registry ) → GitOps( Argo CD ) → 集群( app-sample )。

## 部署位置

| 项 | 值 |
| --- | --- |
| Namespace | `app-sample` |
| 镜像 | `nginx:alpine`（替换为真实业务镜像） |
| Service | `app-sample.app-sample.svc.cluster.local:80` (ClusterIP) |
| Ingress | `/application` → `app-sample:80` |
| 访问 | `http://localhost:30080/application/` |

## 文件

```text
application/
├── namespace.yaml    # app-sample
├── deployment.yaml   # nginx:alpine, 80
├── service.yaml      # ClusterIP 80
├── ingress.yaml      # /application
├── install.sh
├── uninstall.sh
└── README.md
```

## 安装 / 卸载

```bash
cd application && chmod +x install.sh uninstall.sh
./install.sh
./uninstall.sh
```

## 说明 Notes

- 这是**骨架**：把 `deployment.yaml` 的 `image` 换成真实业务镜像即可上线。
- 多业务可按 `app-<name>` 命名 namespace，各自带 Ingress path（如 `/app-foo`）。
- 部署后首页 `application` 卡片即可点击。
