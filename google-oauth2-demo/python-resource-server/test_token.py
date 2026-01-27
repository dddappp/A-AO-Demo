import jwt
import requests
import json
import logging

# 配置日志
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

# 认证服务器配置
AUTH_SERVER_URL = "https://api.u2511175.nyat.app:55139"
JWKS_URL = "https://api.u2511175.nyat.app:55139/oauth2/jwks"

# 获取JWKS
def get_jwks():
    try:
        logger.info(f"Fetching JWKS from {JWKS_URL}")
        response = requests.get(JWKS_URL, verify=False, timeout=10)
        if response.status_code == 200:
            jwks = response.json()
            logger.info(f"Successfully fetched JWKS with {len(jwks.get('keys', []))} keys")
            return jwks
        else:
            logger.error(f"Failed to fetch JWKS: HTTP {response.status_code}")
            return None
    except Exception as e:
        logger.error(f"Error fetching JWKS: {e}")
        return None

# 验证token
def validate_token(token):
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
                    # 尝试使用不同的方法转换JWK为密钥
                    try:
                        # 方法1: 使用jwt.algorithms.RSAAlgorithm.from_jwk
                        key = jwt.algorithms.RSAAlgorithm.from_jwk(jwk_json)
                        logger.debug("Successfully converted JWK to key using RSAAlgorithm.from_jwk")
                    except Exception as e:
                        logger.error(f"Error converting JWK to key using RSAAlgorithm.from_jwk: {e}")
                        # 方法2: 手动构建密钥
                        try:
                            from cryptography.hazmat.primitives.asymmetric import rsa
                            from cryptography.hazmat.primitives import serialization
                            import base64
                            import json
                            
                            # 解码base64url编码的n和e
                            def base64url_decode(input_str):
                                # 处理填充
                                input_str = input_str.replace('-', '+').replace('_', '/')
                                padding = 4 - (len(input_str) % 4)
                                if padding != 4:
                                    input_str += '=' * padding
                                return base64.b64decode(input_str)
                            
                            # 从JWK中提取n和e
                            n = int.from_bytes(base64url_decode(jwk['n']), byteorder='big')
                            e = int.from_bytes(base64url_decode(jwk['e']), byteorder='big')
                            
                            # 创建RSA公钥
                            public_key = rsa.RSAPublicNumbers(e, n).public_key()
                            
                            # 序列化公钥
                            key = public_key.public_bytes(
                                encoding=serialization.Encoding.PEM,
                                format=serialization.PublicFormat.SubjectPublicKeyInfo
                            )
                            logger.debug("Successfully converted JWK to key using manual method")
                        except Exception as e:
                            logger.error(f"Error converting JWK to key using manual method: {e}")
                    
                    if key:
                        break
                except Exception as e:
                    logger.error(f"Error converting JWK to key: {e}")
                    import traceback
                    logger.error(f"Traceback: {traceback.format_exc()}")
                    continue
        
        if not key:
            logger.warning(f"No key found for kid: {kid}")
            return False, "Key not found"
        
        # 验证Token签名和声明
        try:
            logger.debug(f"Attempting to decode token with key type: {type(key)}")
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
        import traceback
        logger.error(f"Traceback: {traceback.format_exc()}")
        return False, str(e)

# 测试函数
if __name__ == "__main__":
    # 从用户输入获取token
    token = input("请输入要验证的token: ")
    
    if not token:
        logger.error("Token不能为空")
        exit(1)
    
    # 验证token
    valid, result = validate_token(token)
    
    if valid:
        logger.info("Token验证成功!")
        logger.info(f"用户: {result.get('sub')}")
        logger.info(f"用户ID: {result.get('userId')}")
        logger.info(f"邮箱: {result.get('email')}")
        logger.info(f"权限: {result.get('authorities')}")
    else:
        logger.error(f"Token验证失败: {result}")
