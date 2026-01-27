"""
异构资源服务器 - Python Flask 实现
用于验证来自 Spring Boot 认证服务器的 JWT Token
"""
import jwt
import requests
import json
from flask import Flask, request, jsonify
from flask_cors import CORS
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

# 配置CORS允许来自不同域的请求
CORS(app, resources={
    r"/*": {
        "origins": ["http://localhost:5173", "http://localhost:8081", "https://api.u2511175.nyat.app:55139"],
        "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        "allow_headers": ["Authorization", "Content-Type"],
        "supports_credentials": True
    }
})

# 认证服务器配置
AUTH_SERVER_URL = "https://api.u2511175.nyat.app:55139"
JWKS_URL = "https://api.u2511175.nyat.app:55139/oauth2/jwks"

# JWKS缓存
jwks_cache = None
cache_time = 0
CACHE_DURATION = 3600  # 1小时

def get_jwks():
    """获取并缓存JWKS"""
    global jwks_cache, cache_time
    import time
    
    current_time = time.time()
    if jwks_cache and (current_time - cache_time) < CACHE_DURATION:
        return jwks_cache
    
    try:
        logger.info(f"Fetching JWKS from {JWKS_URL}")
        response = requests.get(JWKS_URL, verify=False, timeout=10)
        if response.status_code == 200:
            jwks_cache = response.json()
            cache_time = current_time
            logger.info(f"Successfully fetched JWKS with {len(jwks_cache.get('keys', []))} keys")
            return jwks_cache
        else:
            logger.error(f"Failed to fetch JWKS: HTTP {response.status_code}")
            return None
    except Exception as e:
        logger.error(f"Error fetching JWKS: {e}")
        return None

def validate_token(token):
    """验证JWT Token"""
    try:
        # 解析Token头获取 kid 和 alg
        header = jwt.get_unverified_header(token)
        kid = header.get('kid')
        alg = header.get('alg', 'RS256')
        
        logger.debug(f"Token header: kid={kid}, alg={alg}")
        
        # 获取JWKS
        jwks = get_jwks()
        if not jwks:
            logger.error("Failed to get JWKS")
            return False, "Failed to fetch JWKS from auth server"
        
        # 根据 kid 查找对应的密钥
        key = None
        for jwk in jwks.get('keys', []):
            if jwk.get('kid') == kid:
                try:
                    logger.debug(f"Found matching key with kid: {kid}")
                    logger.debug(f"JWK: {json.dumps(jwk, indent=2)}")
                    jwk_json = json.dumps(jwk)
                    logger.debug(f"JWK JSON: {jwk_json}")
                    key = jwt.algorithms.RSAAlgorithm.from_jwk(jwk_json)
                    logger.debug(f"Successfully converted JWK to key")
                    break
                except Exception as e:
                    logger.error(f"Error converting JWK to key: {e}")
                    import traceback
                    logger.error(f"Traceback: {traceback.format_exc()}")
                    continue
        
        if not key:
            logger.warning(f"No key found for kid: {kid}")
            # 如果没有指定 kid 或找不到，尝试使用第一个密钥
            if jwks.get('keys') and len(jwks['keys']) > 0:
                try:
                    logger.debug("Trying to use first available key")
                    key = jwt.algorithms.RSAAlgorithm.from_jwk(json.dumps(jwks['keys'][0]))
                except Exception as e:
                    logger.error(f"Error using default key: {e}")
                    return False, "Invalid key"
        
        if not key:
            logger.error("No valid key available")
            return False, "Key not found"
        
        # 验证Token签名和声明
        try:
            decoded = jwt.decode(
                token,
                key,
                algorithms=[alg],
                audience="resource-server",
                issuer="https://auth.example.com",
                options={"verify_exp": True}
            )
            logger.info(f"Token validated successfully for user: {decoded.get('sub')}")
            return True, decoded
        except jwt.ExpiredSignatureError:
            logger.warning("Token has expired")
            return False, "Token expired"
        except jwt.InvalidTokenError as e:
            logger.warning(f"Invalid token: {e}")
            return False, f"Invalid token: {str(e)}"
            
    except Exception as e:
        logger.error(f"Unexpected error validating token: {e}")
        return False, str(e)

@app.route('/health', methods=['GET'])
def health():
    """健康检查端点"""
    return jsonify({
        "status": "ok",
        "service": "python-resource-server",
        "auth_server": AUTH_SERVER_URL
    })

@app.route('/api/protected', methods=['GET'])
def protected_resource():
    """受保护的API端点 - 需要有效的Bearer Token"""
    logger.debug("Protected resource request received")
    
    # 从Authorization头获取Token
    auth_header = request.headers.get('Authorization')
    if not auth_header:
        logger.warning("Missing Authorization header")
        return jsonify({"error": "Authorization header required"}), 401
    
    # 提取Bearer Token
    if not auth_header.startswith('Bearer '):
        logger.warning("Invalid Authorization header format")
        return jsonify({"error": "Invalid Authorization header format"}), 401
    
    token = auth_header[7:]  # 移除 "Bearer " 前缀
    
    # 验证Token
    valid, result = validate_token(token)
    if not valid:
        logger.warning(f"Token validation failed: {result}")
        return jsonify({"error": "Invalid token", "details": result}), 401
    
    # Token有效，返回受保护的资源
    logger.info(f"Returning protected resource for user: {result.get('sub')}")
    return jsonify({
        "message": "Access granted",
        "timestamp": __import__('datetime').datetime.now().isoformat(),
        "user": {
            "id": result.get('userId'),
            "username": result.get('sub'),
            "email": result.get('email'),
            "authorities": result.get('authorities', [])
        },
        "resource": {
            "data": "This is protected data from Python resource server",
            "accessed_at": __import__('datetime').datetime.now().isoformat(),
            "token_claims": {
                "aud": result.get('aud'),
                "iss": result.get('iss'),
                "iat": result.get('iat'),
                "exp": result.get('exp')
            }
        }
    })

@app.route('/api/protected/info', methods=['GET'])
def protected_info():
    """返回受保护资源的信息"""
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        return jsonify({"error": "Unauthorized"}), 401
    
    token = auth_header[7:]
    valid, result = validate_token(token)
    if not valid:
        return jsonify({"error": "Invalid token"}), 401
    
    return jsonify({
        "info": "This resource is protected by Spring Boot OAuth2 server",
        "current_user": result.get('sub'),
        "allowed_resources": ["/api/protected", "/api/protected/info"],
        "auth_server": AUTH_SERVER_URL
    })

@app.errorhandler(404)
def not_found(error):
    """处理404错误"""
    return jsonify({"error": "Endpoint not found"}), 404

@app.errorhandler(500)
def internal_error(error):
    """处理500错误"""
    logger.error(f"Internal server error: {error}")
    return jsonify({"error": "Internal server error"}), 500

if __name__ == '__main__':
    logger.info(f"Starting Python Resource Server")
    logger.info(f"Auth Server: {AUTH_SERVER_URL}")
    logger.info(f"JWKS URL: {JWKS_URL}")
    
    # 生产环境应使用 gunicorn，开发环境使用 Flask 内置服务器
    app.run(
        host='0.0.0.0',
        port=5002,
        debug=True,
        use_reloader=True
    )
