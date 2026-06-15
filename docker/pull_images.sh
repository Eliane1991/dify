#!/bin/bash

# 镜像列表（去重后）
images=(
    "ghcr.io/chroma-core/chroma:1.5.9"
    "containers.intersystems.com/intersystems/iris-community:2025.3"
    "container-registry.oracle.com/database/free:latest"
    "quay.io/coreos/etcd:v3.5.5"
    "elasticsearch:latest"
    "kibana:latest"
    "downloads.unstructured.io/unstructured-io/unstructured-api:latest"
)

# 国内镜像加速器列表
mirrors=(
    "docker.mirrors.ustc.edu.cn"
    "hub-mirror.c.163.com"
    "mirror.baidubce.com"
    "registry.linkease.net:5443"
)

echo "开始拉取 ${#images[@]} 个镜像..."
echo "========================================"

success_count=0
failed_count=0

for img in "${images[@]}"; do
    echo ""
    echo "[$((success_count + failed_count + 1))/${#images[@]}] 拉取: $img"
    echo "----------------------------------------"

    # 检查本地是否已存在该镜像
    if docker image inspect "$img" &>/dev/null; then
        echo "⏭️  跳过: $img (本地已存在)"
        ((success_count++))
        continue
    fi

    # 尝试直接拉取原镜像
    if docker pull "$img"; then
        echo "✅ 成功: $img"
        ((success_count++))
        continue
    fi

    # 如果直接拉取失败，尝试使用国内镜像加速器
    pulled=false
    for mirror in "${mirrors[@]}"; do
        # 根据不同类型的镜像仓库转换地址格式
        if [[ "$img" == "ghcr.io/"* ]]; then
            # ghcr.io 镜像
            mirror_img="${mirror}/ghcr/${img#ghcr.io/}"
        elif [[ "$img" == "quay.io/"* ]]; then
            # quay.io 镜像
            mirror_img="${mirror}/quay/${img#quay.io/}"
        elif [[ "$img" == "docker.elastic.co/"* ]]; then
            # elastic 镜像
            mirror_img="${mirror}/elastic/${img#docker.elastic.co/}"
        elif [[ "$img" == "docker.io/"* ]]; then
            # docker.io/library/xxx -> mirror/library/xxx
            mirror_img="${mirror}${img#docker.io}"
        elif [[ "$img" == */* ]]; then
            # 其他格式尝试转换
            mirror_img="${mirror}/library/${img##*/}"
        else
            # 简单镜像名
            mirror_img="${mirror}/library/${img}"
        fi

        echo "尝试使用镜像加速器 $mirror: $mirror_img"
        if docker pull "$mirror_img"; then
            # 拉取成功后，重新打标签为原镜像名
            echo "📦 正在修复镜像名称..."
            docker tag "$mirror_img" "$img"
            # 删除临时标签
            docker rmi "$mirror_img" &>/dev/null
            echo "✅ 成功: $img (通过加速器 $mirror)"
            ((success_count++))
            pulled=true
            break
        fi
    done

    if [ "$pulled" = false ]; then
        echo "❌ 失败: $img (继续下一个...)"
        ((failed_count++))
    fi
done

echo ""
echo "========================================"
echo "拉取完成！"
echo "成功: $success_count"
echo "失败: $failed_count"