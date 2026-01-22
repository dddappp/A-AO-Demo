# OAuth2 Demo Frontend

这是一个使用React构建的前后端分离OAuth2登录演示应用的前端部分。

## 技术栈

- **React 18** - UI框架
- **TypeScript** - 类型安全
- **Vite** - 构建工具和开发服务器
- **Tailwind CSS** - CSS框架
- **Axios** - HTTP客户端
- **React Router** - 路由管理

## 项目结构

```
frontend/
├── public/                 # 静态资源
│   ├── index.html
│   └── favicon.ico
├── src/
│   ├── components/         # React组件
│   │   ├── AuthButton.tsx  # 登录按钮组件
│   │   ├── UserInfo.tsx    # 用户信息显示组件
│   │   └── TokenValidator.tsx # Token验证组件
│   ├── pages/             # 页面组件
│   │   ├── LoginPage.tsx   # 登录页面
│   │   ├── TestPage.tsx    # 测试页面
│   │   └── HomePage.tsx    # 首页
│   ├── hooks/             # 自定义Hooks
│   │   ├── useAuth.ts      # 认证状态管理
│   │   └── useApi.ts       # API调用
│   ├── services/          # API服务
│   │   ├── authService.ts  # 认证相关API
│   │   └── apiClient.ts    # HTTP客户端配置
│   ├── types/             # TypeScript类型定义
│   │   └── index.ts
│   ├── utils/             # 工具函数
│   │   └── constants.ts    # 常量定义
│   ├── App.tsx            # 主应用组件
│   ├── main.tsx           # 应用入口
│   └── index.css          # 全局样式
├── package.json           # 项目依赖
├── vite.config.ts         # Vite配置
├── tailwind.config.js     # Tailwind配置
└── tsconfig.json          # TypeScript配置
```

## 功能特性

✅ **完整的OAuth2登录**: 支持Google、GitHub、Twitter三种登录方式
✅ **现代化UI**: 使用React和Tailwind CSS构建
✅ **用户信息显示**: 显示用户基本信息和提供商特定数据
✅ **Token验证**: 完整的JWT和OAuth2 Token验证功能
✅ **响应式设计**: 支持移动端和桌面端
✅ **TypeScript**: 完整的类型安全

## 快速开始

### 环境要求

- Node.js 16+
- npm 或 yarn

### 安装依赖

```bash
cd frontend
npm install
```

### 开发环境运行

```bash
npm run dev
```

应用将在 `http://localhost:5173` 启动。

### 构建生产版本

```bash
npm run build
```

构建产物将输出到 `dist/` 目录。

### 预览生产构建

```bash
npm run preview
```

## 环境变量

创建 `.env.local` 文件配置API地址：

```env
VITE_API_BASE_URL=http://localhost:8080
VITE_OAUTH_REDIRECT_URL=http://localhost:5173/auth/callback
```

## API接口

### 认证相关

- `GET /api/user` - 获取当前用户信息
- `POST /api/logout` - 用户登出
- `POST /api/validate-google-token` - 验证Google Token
- `POST /api/validate-github-token` - 验证GitHub Token
- `POST /api/validate-twitter-token` - 验证Twitter Token

### OAuth2登录

- `/oauth2/authorization/google` - Google登录
- `/oauth2/authorization/github` - GitHub登录
- `/oauth2/authorization/twitter` - Twitter登录

## 页面功能

### 🏠 首页 (/)
- 应用介绍和功能说明
- 导航到登录页面
- 显示当前前端实现类型

### 🔐 登录页面 (/login)
- 三种OAuth2提供商的登录按钮
- 响应式设计，支持移动端
- 自动重定向到测试页面

### 🧪 测试页面 (/test)
- 显示当前用户信息和头像
- 提供商特定信息展示
- Token验证功能
- 登出功能

## 开发指南

### 添加新的OAuth2提供商

1. 在 `services/authService.ts` 中添加新的登录URL
2. 在 `pages/LoginPage.tsx` 中添加新的登录按钮
3. 在 `types/index.ts` 中添加提供商类型
4. 在后端API控制器中添加相应的处理逻辑

### 自定义样式

项目使用Tailwind CSS进行样式管理：

```tsx
<div className="bg-blue-500 text-white p-4 rounded-lg shadow-md">
  自定义样式
</div>
```

### 错误处理

使用 `try-catch` 处理API错误：

```tsx
try {
  const response = await authService.getCurrentUser();
  // 处理成功响应
} catch (error) {
  console.error('API错误:', error);
  // 显示错误提示
}
```

## 部署

### 开发环境

**当前主要做法（前后端一体化开发模式）**：

1. **前端构建集成**：使用 `npm run build` 将前端构建并自动复制到 Spring Boot 静态资源目录
2. **一体化启动**：Spring Boot 应用同时提供前端页面和后端API服务
3. **开发流程**：
   ```bash
   cd frontend
   npm run build  # 构建并自动复制到 ../src/main/resources/static/
   cd ..
   mvn spring-boot:run  # 启动一体化应用
   ```
4. **访问地址**：前端和后端都在 `http://localhost:8081`

**传统分离开发模式**（可选）：

前端运行在 `http://localhost:5173`，后端运行在 `http://localhost:8080`。
- 前端：`npm run dev`
- 后端：`mvn spring-boot:run`

### 生产环境

**推荐的一体化部署**：

1. 构建前端：`npm run build`（自动集成到Spring Boot）
2. 构建Spring Boot应用：`mvn clean package`
3. 部署单个JAR文件：`java -jar target/*.jar`
4. 设置环境变量和外部配置

**传统分离部署**：

1. 构建前端：`npm run build`
2. 将 `dist/` 目录部署到静态文件服务器
3. 配置反向代理将API请求转发到后端
4. 更新环境变量为生产域名

### Nginx配置示例

```nginx
server {
    listen 80;
    server_name your-domain.com;

    # 前端静态文件
    location / {
        root /path/to/dist;
        try_files $uri $uri/ /index.html;
    }

    # API代理到后端
    location /api/ {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # OAuth2回调代理
    location /oauth2/ {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 注意事项

1. **CORS配置**: 确保后端正确配置了CORS策略
2. **HTTPS**: 生产环境必须使用HTTPS以确保OAuth2安全
3. **环境变量**: 不要在代码中硬编码API地址和密钥
4. **安全性**: 前端Token验证仅用于演示，实际应用中应在后端验证

## 许可证

MIT License
