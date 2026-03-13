# PHP-FPM Docker 启动说明

## 📋 文件说明

| 文件 | 说明 |
|------|------|
| `php-fpm.sh` | PHP-FPM 启动脚本 |
| `php-fpm.conf` | PHP-FPM 配置文件（standalone 模式） |

---

## 🚀 使用方法

### 方式 1: 在 Docker 启动时自动运行

**Dockerfile**:
```dockerfile
FROM nginx:alpine

# 安装 PHP-FPM
RUN apk add --no-cache php-fpm

# 复制配置文件
COPY php-fpm.conf /etc/php/fpm/php-fpm.conf
COPY www.conf /etc/php/fpm/php-fpm.d/www.conf

# 复制启动脚本
COPY entrypoint.d/php-fpm.sh /entrypoint.d/20-php-fpm.sh
RUN chmod +x /entrypoint.d/20-php-fpm.sh

# 启动命令（nginx 的 entrypoint 会自动运行 entrypoint.d 中的脚本）
CMD ["nginx", "-g", "daemon off;"]
```

### 方式 2: 手动启动

```bash
# 复制启动脚本到容器
docker cp entrypoint.d/php-fpm.sh <container>:/entrypoint.d/

# 进入容器执行
docker exec -it <container> /entrypoint.d/php-fpm.sh
```

### 方式 3: 直接在容器中运行

```bash
docker exec -it <container> sh -c "
    mkdir -p /run/php /var/log/php-fpm
    php-fpm --daemonize
"
```

---

## 🔧 配置说明

### TCP 监听（推荐 Docker 使用）

```ini
listen = 127.0.0.1:9000
listen.allowed_clients = 127.0.0.1
```

### Unix Socket 监听（性能更好）

```ini
listen = /run/php/php-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660
```

---

## 📊 日志文件

| 日志 | 路径 |
|------|------|
| 启动日志 | `/var/log/php-fpm.log` |
| 错误日志 | `/var/log/php-fpm-error.log` |
| 访问日志 | `/var/log/php-fpm-access.log` |
| 慢日志 | `/var/log/php-fpm-slow.log` |

---

## 🛠️ 故障排查

### 1. 检查 PHP-FPM 是否运行

```bash
docker exec <container> pgrep -x php-fpm
# 输出 PID 表示运行正常
```

### 2. 检查监听端口

```bash
docker exec <container> netstat -tlnp | grep 9000
# 或
docker exec <container> ss -tlnp | grep 9000
```

### 3. 查看日志

```bash
docker exec <container> tail -f /var/log/php-fpm.log
docker exec <container> tail -f /var/log/php-fpm-error.log
```

### 4. 测试 PHP

```bash
docker exec <container> php -r "echo 'OK';"
```

### 5. 测试上传接口

```bash
curl -k -X POST "https://img.mtdcy.top:8443/upload.php?path=/test/" \
  -F "file=@/path/to/test.jpg" \
  -H "Accept: application/json"
```

---

## ⚙️ 性能优化

### 调整进程池大小

根据容器资源调整：

```ini
; 小容器（512MB RAM）
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 2
pm.max_spare_servers = 5

; 中容器（1GB RAM）
pm.max_children = 25
pm.start_servers = 3
pm.min_spare_servers = 3
pm.max_spare_servers = 10

; 大容器（2GB+ RAM）
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
```

### 内存限制

```ini
php_admin_value[memory_limit] = 256M
```

---

## 📝 注意事项

1. **权限问题**: 确保上传目录对 `www-data` 可写
2. **日志目录**: 确保日志目录存在且可写
3. **临时目录**: 确保 `/tmp` 有足够空间
4. **Docker 重启**: PHP-FPM 会随容器重启自动启动

---

**最后更新**: 2026-03-13  
**维护者**: mtdcy.chen@gmail.com
