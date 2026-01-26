import jwt
import json

# 从前端日志中复制的令牌
token = "eyJraWQiOiJrZXktMSIsImFsZyI6IlJTMjU2In0.eyJhdWQiOiJyZXNvdXJjZS1zZXJ2ZXIiLCJpc3MiOiJodHRwczovL2F1dGguZXhhbXBsZS5jb20iLCJ0eXBlIjoiYWNjZXNzIiwidXNlcklkIjoiMDk1ZDMxYjUtNjQxNC00MDVhLWE1ODEtZGZlYjllNThjZjE1IiwiZW1haWwiOiJ0ZXN0bG9jYWxAZXhhbXBsZS5jb20iLCJhdXRob3JpdGllcyI6WyJST0xFX1VTRVIiXSwianRpIjoiZWM1YjZlMDUtZjcyMi00YTY4LTk1ZDQtMTUzMjQyODY0MmMzIiwic3ViIjoidGVzdGxvY2FsIiwiaWF0IjoxNzY5MzUzMzc1LCJleHAiOjE3NjkzNTY5NzV9.eDdPpGgs5P6QnUCIKcmRp_wtqJ3LpFPfDuhiAE00Y4eSZYw5f7AyvYS90ddmkpjm-MAaVmj5D3gP0Fv04VRpyejdGoYrtZdvlVHGcuoxnGklC1GxRshbKYAcejW6s8iDtm3NhFwsABxTGmR0q_9IwppmO3NebWuZ1NKNHWD_nEXTeT8aAQI7GxM0E5I_pYA-gJqLDhimaCIntCBEL-093_m4CUHNDBSHsEQmhejBUAw10l4Lj2GIa1RR_LrRkQJcruzJwKbxChSe_G1kl0XADy5MYUgWjncjkI3AT2WMaapl4pIXC4qwIKm8H6aa4_LOvbbjRkcZKf-JsJtmgInC6g"

# 解码令牌头
token_parts = token.split('.')
header_part = token_parts[0]
payload_part = token_parts[1]

import base64

def decode_base64url(input_str):
    # 修复base64url编码
    input_str = input_str.replace('-', '+').replace('_', '/')
    padding = '=' * ((4 - len(input_str) % 4) % 4)
    input_str += padding
    return base64.b64decode(input_str)

# 解码令牌头和载荷
header = json.loads(decode_base64url(header_part))
payload = json.loads(decode_base64url(payload_part))

print("令牌头:")
print(json.dumps(header, indent=2))
print("\n令牌载荷:")
print(json.dumps(payload, indent=2))

# 检查令牌是否过期
import time
current_time = time.time()
if payload.get('exp') < current_time:
    print("\n❌ 令牌已过期")
else:
    print("\n✅ 令牌未过期")
    print(f"   过期时间: {time.ctime(payload.get('exp'))}")
    print(f"   当前时间: {time.ctime(current_time)}")
    print(f"   剩余时间: {payload.get('exp') - current_time:.2f} 秒")

# 检查令牌的issuer和audience
print("\n令牌验证信息:")
print(f"   Issuer: {payload.get('iss')}")
print(f"   Audience: {payload.get('aud')}")
print(f"   Subject: {payload.get('sub')}")
print(f"   User ID: {payload.get('userId')}")
print(f"   Email: {payload.get('email')}")
print(f"   Authorities: {payload.get('authorities')}")
print(f"   Token Type: {payload.get('type')}")
