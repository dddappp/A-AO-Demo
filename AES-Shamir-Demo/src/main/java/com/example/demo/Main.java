package com.example.demo;

import com.codahale.shamir.Scheme;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.security.SecureRandom;
import java.security.Security;
import java.util.*;

public class Main {
    public static void main(String[] args) throws Exception {
        // 参数
        final int KEY_SIZE = 256;
        final int IV_SIZE = 12; // GCM 推荐 96-bit
        final int TAG_SIZE = 128; // GCM 认证标签长度
        final int N = 10, T = 7; // Shamir 分片 n=10, t=7

        System.out.println("\n=== 1. 生成 AES-256-GCM 密钥和随机 IV ===");
        // 1.1 生成 AES 密钥
        KeyGenerator kg = KeyGenerator.getInstance("AES");
        kg.init(KEY_SIZE);
        SecretKey aesKey = kg.generateKey();
        System.out.println("AES 密钥: " + bytesToHex(aesKey.getEncoded()));

        // 1.2 生成随机 IV
        byte[] iv = new byte[IV_SIZE];
        new SecureRandom().nextBytes(iv);
        System.out.println("随机 IV: " + bytesToHex(iv));

        // 待加密明文
        String plaintext = "示例数字藏品内容";
        System.out.println("明文: " + plaintext);

        System.out.println("\n=== 2. 使用 AES-256-GCM 加密 ===");
        // 2.1 初始化 Cipher
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        GCMParameterSpec gcmSpec = new GCMParameterSpec(TAG_SIZE, iv);
        cipher.init(Cipher.ENCRYPT_MODE, aesKey, gcmSpec);

        // 2.2 加密并获取密文
        byte[] ciphertext = cipher.doFinal(plaintext.getBytes());
        System.out.println("密文 (Hex): " + bytesToHex(ciphertext));

        // 2.3 将 IV 和密文组合成完整的加密数据（实际应用中的保存格式）
        byte[] encryptedData = new byte[IV_SIZE + ciphertext.length];
        System.arraycopy(iv, 0, encryptedData, 0, IV_SIZE); // 前 IV_SIZE 字节存储 IV
        System.arraycopy(ciphertext, 0, encryptedData, IV_SIZE, ciphertext.length); // 后面存储密文
        System.out.println("完整加密数据 (IV + 密文): " + bytesToHex(encryptedData));

        System.out.println("\n=== 3. Shamir " + T + "-of-" + N + " 分片 ===");
        // 3.1 使用 codahale/shamir 拆分
        Scheme scheme = new Scheme(new SecureRandom(), N, T);
        Map<Integer, byte[]> shares = scheme.split(aesKey.getEncoded());

        // 3.2 打印各分片
        shares.forEach((idx, share) -> System.out.printf("节点 %2d 的分片: %s%n", idx, bytesToHex(share)));

        System.out.println("\n=== 4. 模拟至少 " + T + " 个节点同意，重构秘钥 ===");
        // 4.1 随机选取 T 个分片
        List<Integer> keys = new ArrayList<>(shares.keySet());
        Collections.shuffle(keys);
        Map<Integer, byte[]> subset = new HashMap<>();
        for (int i = 0; i < T; i++) {
            int idx = keys.get(i);
            subset.put(idx, shares.get(idx));
            System.out.printf("选取分片: 节点 %2d%n", idx);
        }

        // 4.2 重构 AES 密钥
        byte[] reconstructed = scheme.join(subset);
        System.out.println("重构秘钥: " + bytesToHex(reconstructed));

        // 校验重构是否与原密钥一致
        System.out.println("重构校验: " + Arrays.equals(reconstructed, aesKey.getEncoded()));

        System.out.println("\n=== 5. 使用重构秘钥解密 ===");
        // 5.1 从完整加密数据中提取 IV 和密文
        byte[] extractedIv = new byte[IV_SIZE];
        byte[] extractedCiphertext = new byte[encryptedData.length - IV_SIZE];
        System.arraycopy(encryptedData, 0, extractedIv, 0, IV_SIZE); // 提取 IV
        System.arraycopy(encryptedData, IV_SIZE, extractedCiphertext, 0, extractedCiphertext.length); // 提取密文

        System.out.println("从存储数据中提取的 IV: " + bytesToHex(extractedIv));
        System.out.println("从存储数据中提取的密文: " + bytesToHex(extractedCiphertext));

        // 5.2 使用提取的 IV 构造 GCMParameterSpec
        GCMParameterSpec extractedGcmSpec = new GCMParameterSpec(TAG_SIZE, extractedIv);
        SecretKeySpec keySpec = new SecretKeySpec(reconstructed, "AES");
        Cipher decipher = Cipher.getInstance("AES/GCM/NoPadding");
        decipher.init(Cipher.DECRYPT_MODE, keySpec, extractedGcmSpec);

        // 5.3 解密
        byte[] decrypted = decipher.doFinal(extractedCiphertext);
        String recovered = new String(decrypted);
        System.out.println("解密得到明文: " + recovered);

        System.out.println("\n=== 6. 演示错误的 IV 会导致解密失败 ===");
        try {
            // 模拟从存储的数据中"错误地"提取 IV（实际上使用正确的密文，但用错误的 IV）
            byte[] wrongIv = new byte[IV_SIZE];
            new SecureRandom().nextBytes(wrongIv); // 生成错误的 IV
            GCMParameterSpec wrongGcmSpec = new GCMParameterSpec(TAG_SIZE, wrongIv);
            Cipher wrongDecipher = Cipher.getInstance("AES/GCM/NoPadding");
            wrongDecipher.init(Cipher.DECRYPT_MODE, keySpec, wrongGcmSpec);
            // 注意：这里仍然使用 extractedCiphertext（正确的密文），但用错误的 IV
            byte[] wrongResult = wrongDecipher.doFinal(extractedCiphertext);
            System.out.println("错误的 IV 解密结果: " + new String(wrongResult));
        } catch (Exception e) {
            System.out.println("错误的 IV 导致解密失败: " + e.getMessage());
        }

        System.out.println("\n=== 演示完成 ===");
    }

    // 辅助函数：字节数组转 Hex
    private static String bytesToHex(byte[] data) {
        StringBuilder sb = new StringBuilder();
        for (byte b : data) {
            sb.append(String.format("%02X", b));
        }
        return sb.toString();
    }
}
