# 🚀 部署与运维指南

**版本:** 3.0.0  
**支持环境:** Docker + 传统服务器

---

## 目录

1. [本地开发环境](#本地开发环境)
2. [Docker 部署](#docker-部署)
3. [生产环境配置](#生产环境配置)
4. [监控与故障排查](#监控与故障排查)

---

## 本地开发环境

### 快速启动

```bash
# 1. 克隆项目
git clone <repo-url>
cd user-auth-system

# 2. 启动后端 (自动使用 SQLite)
cd backend
mvn clean install
mvn spring-boot:run

# 输出应该包含:
# Started AuthApplication in X.XXX seconds
# Listening on http://localhost:8080/api

# 3. 启动前端 (新终端)
cd ../frontend
npm install
npm run dev

# 输出应该包含:
# VITE v5.0.0  ready in XXX ms
# ➜  Local:   http://localhost:5173/

# 4. 打开浏览器
# 访问 http://localhost:5173
```

### 测试登录

```
用户名: test@example.com
密码:   password123
```

---

## Docker 部署

### docker-compose.yml

```yaml
version: '3.8'

services:
  # PostgreSQL 数据库
  postgres:
    image: postgres:15-alpine
    container_name: auth_postgres
    environment:
      POSTGRES_DB: auth_db
      POSTGRES_USER: auth_user
      POSTGRES_PASSWORD: ${DB_PASSWORD:-auth_password}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backend/src/main/resources/schema-postgresql.sql:/docker-entrypoint-initdb.d/01-schema.sql
      - ./backend/src/main/resources/data-postgresql.sql:/docker-entrypoint-initdb.d/02-data.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U auth_user"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - auth_network

  # Spring Boot 后端
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: auth_backend
    environment:
      SPRING_PROFILES_ACTIVE: prod
      DB_HOST: postgres
      DB_PORT: 5432
      DB_NAME: auth_db
      DB_USERNAME: auth_user
      DB_PASSWORD: ${DB_PASSWORD:-auth_password}
      GOOGLE_CLIENT_ID: ${GOOGLE_CLIENT_ID}
      GOOGLE_CLIENT_SECRET: ${GOOGLE_CLIENT_SECRET}
    ports:
      - "8080:8080"
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/api/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - auth_network

  # React 前端
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: auth_frontend
    environment:
      VITE_API_URL: http://localhost:8080/api
      VITE_GOOGLE_CLIENT_ID: ${GOOGLE_CLIENT_ID}
    ports:
      - "3000:80"
    depends_on:
      - backend
    networks:
      - auth_network

volumes:
  postgres_data:

networks:
  auth_network:
    driver: bridge
```

### Dockerfile (后端)

```dockerfile
# backend/Dockerfile

# 构建阶段
FROM maven:3.9-eclipse-temurin-17 AS builder

WORKDIR /app

COPY pom.xml .
RUN mvn dependency:go-offline

COPY . .
RUN mvn clean package -DskipTests

# 运行阶段
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# 创建非 root 用户
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# 从构建阶段复制 JAR
COPY --from=builder /app/target/user-auth-system-*.jar app.jar

# 设置权限
RUN chown -R appuser:appgroup /app
USER appuser

EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:8080/api/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
```

### Dockerfile (前端)

```dockerfile
# frontend/Dockerfile

# 构建阶段
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# 运行阶段
FROM nginx:alpine

COPY --from=builder /app/dist /usr/share/nginx/html

# Nginx 配置
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

### nginx.conf

```nginx
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html index.htm;

    # 处理 SPA 路由
    location / {
        try_files $uri $uri/ /index.html;
    }

    # API 反向代理
    location /api {
        proxy_pass http://backend:8080/api;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 缓存静态资源
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

### 启动容器

```bash
# 1. 设置环境变量
export DB_PASSWORD=secure_password_123
export GOOGLE_CLIENT_ID=your-google-client-id
export GOOGLE_CLIENT_SECRET=your-google-client-secret

# 2. 启动所有容器
docker-compose up -d

# 3. 查看日志
docker-compose logs -f

# 4. 停止容器
docker-compose down

# 5. 清理容器和卷
docker-compose down -v
```

---

## 生产环境配置

### HTTPS 配置 (Let's Encrypt)

```bash
# 使用 Certbot 获取免费证书
sudo apt-get install certbot python3-certbot-nginx

# 生成证书
sudo certbot certonly --standalone -d yourdomain.com

# 证书位置
# /etc/letsencrypt/live/yourdomain.com/fullchain.pem
# /etc/letsencrypt/live/yourdomain.com/privkey.pem
```

### Nginx 反向代理

```nginx
# /etc/nginx/sites-available/auth-system

upstream backend {
    server 127.0.0.1:8080;
}

upstream frontend {
    server 127.0.0.1:3000;
}

# HTTP 重定向到 HTTPS
server {
    listen 80;
    server_name yourdomain.com;
    return 301 https://$server_name$request_uri;
}

# HTTPS 服务
server {
    listen 443 ssl http2;
    server_name yourdomain.com;

    # SSL 证书
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    # SSL 配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # 安全头部
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # 前端
    location / {
        proxy_pass http://frontend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # 后端 API
    location /api {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 启用 Nginx 配置

```bash
# 创建符号链接
sudo ln -s /etc/nginx/sites-available/auth-system /etc/nginx/sites-enabled/

# 测试配置
sudo nginx -t

# 启动 Nginx
sudo systemctl restart nginx
```

### Systemd 服务文件

```ini
# /etc/systemd/system/auth-backend.service

[Unit]
Description=Auth System Backend
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=appuser
WorkingDirectory=/opt/auth-system
Environment="SPRING_PROFILES_ACTIVE=prod"
Environment="DB_HOST=localhost"
Environment="DB_PORT=5432"
Environment="DB_NAME=auth_db"
EnvironmentFile=/etc/auth-system/backend.env

ExecStart=/usr/bin/java -jar /opt/auth-system/backend.jar
Restart=always
RestartSec=10

StandardOutput=journal
StandardError=journal
SyslogIdentifier=auth-backend

[Install]
WantedBy=multi-user.target
```

启动服务：

```bash
sudo systemctl daemon-reload
sudo systemctl enable auth-backend
sudo systemctl start auth-backend
sudo systemctl status auth-backend
```

---

## 监控与故障排查

### 应用健康检查

```bash
# 健康检查端点
curl http://localhost:8080/api/actuator/health

# 响应示例
{
  "status": "UP",
  "components": {
    "db": {
      "status": "UP",
      "details": {
        "database": "PostgreSQL",
        "validationQuery": "isValid()"
      }
    }
  }
}
```

### 查看日志

```bash
# Docker 日志
docker-compose logs -f backend

# 系统日志 (Systemd)
sudo journalctl -u auth-backend -f

# 应用日志文件
less /var/log/auth-system/app.log
```

### 常见问题

#### 1. 数据库连接失败

```
错误: Unable to get a connection, pool error Timeout waiting for idle object

解决:
1. 检查 PostgreSQL 是否运行
2. 验证连接字符串
3. 检查防火墙端口 5432
4. 查看数据库日志
```

#### 2. Cookie 不被保存

```
错误: accessToken Cookie 没有被保存

解决:
1. 确保 withCredentials: true
2. 检查 SameSite 设置
3. 开发环境禁用 Secure 标志
4. 检查 CORS 配置 (Allow-Credentials: true)
```

#### 3. Token 过期导致 401

```
错误: 401 Unauthorized

解决:
1. 自动刷新 Token (前端)
2. 检查 Token 有效期
3. 查看 Token 黑名单
4. 清除 Cookie 并重新登录
```

---

**下一步:** 查看 [06-Quick-Reference.md] 获取快速参考
