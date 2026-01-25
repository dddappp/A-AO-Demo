# Python 异构资源服务器

这是一个 Flask 实现的示例资源服务器，展示了如何验证来自 Spring Boot OAuth2 认证服务器的 JWT Token。

## 功能

- ✅ 从 JWKS 端点获取公钥
- ✅ 验证 JWT Token 签名
- ✅ 支持 Token 过期检查
- ✅ CORS 配置支持跨域请求
- ✅ 受保护的 API 端点
- ✅ Token 缓存以提高性能

## 安装

### 前置条件

- Python 3.8+
- pip

### 设置

```bash
# 创建虚拟环境（推荐）
python3 -m venv venv
source venv/bin/activate  # Linux/macOS
# 或 venv\Scripts\activate  # Windows

# 安装依赖
pip install -r requirements.txt
```

## 运行

```bash
python app.py
```

服务器将在 `http://0.0.0.0:5001` 上启动。

## API 端点

### 健康检查
```bash
GET /health
```

### 受保护资源
```bash
GET /api/protected
Authorization: Bearer <JWT_TOKEN>
```

返回示例：
```json
{
  "message": "Access granted",
  "user": {
    "id": "user-id",
    "username": "username",
    "email": "user@example.com",
    "authorities": ["ROLE_USER"]
  },
  "resource": {
    "data": "This is protected data from Python resource server"
  }
}
```

### 受保护资源信息
```bash
GET /api/protected/info
Authorization: Bearer <JWT_TOKEN>
```

## 配置

编辑 `app.py` 中的以下变量以配置认证服务器：

```python
AUTH_SERVER_URL = "https://api.u2511175.nyat.app:55139"  # 认证服务器地址
JWKS_URL = f"{AUTH_SERVER_URL}/oauth2/jwks"              # JWKS 端点
```

## Token 验证流程

1. 客户端从认证服务器获取 JWT Token
2. 客户端在 Authorization 头中发送 Bearer Token 到资源服务器
3. 资源服务器从认证服务器获取 JWKS（缓存 1 小时）
4. 资源服务器使用 JWKS 中的公钥验证 Token 签名
5. 如果验证成功，返回受保护资源

## 安全考虑

- ✅ Token 签名验证（RS256）
- ✅ Token 过期检查
- ✅ Audience（受众）声明验证
- ✅ Issuer（颁发者）验证
- ✅ CORS 配置限制跨域访问

## 依赖

- **Flask**: Web 框架
- **Flask-CORS**: CORS 支持
- **PyJWT**: JWT Token 处理
- **cryptography**: 密码学库
- **requests**: HTTP 客户端

## 测试

通过以下方式测试受保护端点：

```bash
# 1. 登录获取 Token
TOKEN=$(curl -s -X POST "https://api.u2511175.nyat.app:55139/api/auth/login?username=testboth&password=password123" -H "Content-Type: application/json" | jq -r '.accessToken')

# 2. 使用 Token 访问受保护资源
curl -H "Authorization: Bearer $TOKEN" http://localhost:5001/api/protected
```

## 生产部署

对于生产环境，建议使用 WSGI 应用服务器如 Gunicorn：

```bash
pip install gunicorn
gunicorn -w 4 -b 0.0.0.0:5001 app:app
```

## 许可证

MIT
