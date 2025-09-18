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

/**
 * AES-256-GCM + Shamir 门限分片演示程序
 *
 * 这个程序演示了如何：
 * 1. 使用现代加密算法保护数据
 * 2. 将加密密钥安全地分片存储
 * 3. 通过多方协作重构密钥进行解密
 *
 * 适合初学者的理解：就像把保险箱的钥匙分成7片，存放在10个不同的地方，
 * 需要至少7片钥匙才能打开保险箱。
 */
public class Main {
    public static void main(String[] args) throws Exception {
        // ============ 配置参数 ============
        // 密钥长度：256位AES（非常安全，暴力破解需要亿万年）
        final int KEY_SIZE = 256;
        // 初始化向量长度：12字节（96位），GCM模式的标准要求
        final int IV_SIZE = 12;
        // 认证标签长度：128位，用于验证数据完整性
        final int TAG_SIZE = 128;
        // Shamir分片配置：10个分片中至少7个就能重构密钥
        final int TOTAL_SHARES = 10;  // 总共分片数
        final int REQUIRED_SHARES = 7; // 最少需要分片数

        System.out.println("\n=== 步骤1：生成加密工具（AES密钥和IV） ===");
        System.out.println("想象一下：我们要建一个保险箱，需要一把钥匙和一个开锁密码。");

        // 生成AES密钥（相当于保险箱的钥匙）
        System.out.println("正在生成AES-256密钥...");
        KeyGenerator keyGenerator = KeyGenerator.getInstance("AES");
        keyGenerator.init(KEY_SIZE);
        SecretKey aesKey = keyGenerator.generateKey();
        System.out.println("✅ AES密钥已生成: " + bytesToHex(aesKey.getEncoded()));

        // 生成随机IV（相当于开锁密码）
        System.out.println("正在生成随机IV（初始化向量）...");
        byte[] iv = new byte[IV_SIZE];
        new SecureRandom().nextBytes(iv);
        System.out.println("✅ 随机IV已生成: " + bytesToHex(iv));

        // 要保护的数据（相当于保险箱里的宝物）
        String plaintext = "示例数字藏品内容";
        System.out.println("📦 要保护的宝物: " + plaintext);

        System.out.println("\n=== 步骤2：使用AES-GCM加密宝物 ===");
        System.out.println("现在我们用钥匙和密码把宝物锁进保险箱里。");

        // 初始化加密器
        System.out.println("正在准备加密工具...");
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        GCMParameterSpec gcmSpec = new GCMParameterSpec(TAG_SIZE, iv);
        cipher.init(Cipher.ENCRYPT_MODE, aesKey, gcmSpec);

        // 执行加密
        System.out.println("正在加密数据...");
        byte[] ciphertext = cipher.doFinal(plaintext.getBytes());
        System.out.println("🔒 加密完成！密文: " + bytesToHex(ciphertext));

        // 将IV和密文打包（实际应用中的存储格式）
        System.out.println("正在打包加密数据（IV+密文）...");
        byte[] encryptedData = new byte[IV_SIZE + ciphertext.length];
        System.arraycopy(iv, 0, encryptedData, 0, IV_SIZE); // 前12字节放IV
        System.arraycopy(ciphertext, 0, encryptedData, IV_SIZE, ciphertext.length); // 后面放密文
        System.out.println("📦 完整加密包: " + bytesToHex(encryptedData));

        System.out.println("\n=== 步骤3：将钥匙分成碎片（Shamir分片） ===");
        System.out.println("为了安全，我们要把钥匙分成" + TOTAL_SHARES + "片，存放在不同地方。");
        System.out.println("规则：至少收集" + REQUIRED_SHARES + "片碎片才能重组成完整钥匙。");

        // 使用Shamir算法拆分密钥
        System.out.println("正在拆分钥匙...");
        Scheme scheme = new Scheme(new SecureRandom(), TOTAL_SHARES, REQUIRED_SHARES);
        Map<Integer, byte[]> shares = scheme.split(aesKey.getEncoded());

        // 显示每个碎片
        System.out.println("钥匙碎片分布：");
        shares.forEach((idx, share) ->
            System.out.printf("  🗝️  碎片#%2d: %s%n", idx, bytesToHex(share))
        );

        System.out.println("\n=== 步骤4：收集碎片重组成钥匙 ===");
        System.out.println("现在模拟收集足够的碎片来重组成完整钥匙的过程。");

        // 随机选择REQUIRED_SHARES个碎片（模拟不同人提供碎片）
        System.out.println("正在随机收集" + REQUIRED_SHARES + "片碎片...");
        List<Integer> keys = new ArrayList<>(shares.keySet());
        Collections.shuffle(keys); // 随机打乱顺序
        Map<Integer, byte[]> selectedShares = new HashMap<>();

        System.out.println("收集到的碎片：");
        for (int i = 0; i < REQUIRED_SHARES; i++) {
            int fragmentId = keys.get(i);
            selectedShares.put(fragmentId, shares.get(fragmentId));
            System.out.printf("  ✅ 获得碎片#%2d: %s%n", fragmentId, bytesToHex(shares.get(fragmentId)));
        }

        // 使用收集到的碎片重构完整钥匙
        System.out.println("正在用碎片重组成完整钥匙...");
        byte[] reconstructedKey = scheme.join(selectedShares);
        System.out.println("🔧 重构后的钥匙: " + bytesToHex(reconstructedKey));

        // 验证重构是否正确
        boolean isCorrect = Arrays.equals(reconstructedKey, aesKey.getEncoded());
        System.out.println("🔍 钥匙验证: " + (isCorrect ? "✅ 正确！" : "❌ 错误！"));

        System.out.println("\n=== 步骤5：用重构钥匙打开保险箱 ===");
        System.out.println("现在我们用重组成的钥匙来打开保险箱，取回宝物。");

        // 从存储的加密包中分离IV和密文
        System.out.println("正在从加密包中分离IV和密文...");
        byte[] extractedIv = new byte[IV_SIZE];
        byte[] extractedCiphertext = new byte[encryptedData.length - IV_SIZE];
        System.arraycopy(encryptedData, 0, extractedIv, 0, IV_SIZE); // 前12字节是IV
        System.arraycopy(encryptedData, IV_SIZE, extractedCiphertext, 0, extractedCiphertext.length); // 后面是密文

        System.out.println("📤 提取的IV: " + bytesToHex(extractedIv));
        System.out.println("📤 提取的密文: " + bytesToHex(extractedCiphertext));

        // 用重构的钥匙和提取的IV解密
        System.out.println("正在用重构钥匙解锁...");
        GCMParameterSpec extractedGcmSpec = new GCMParameterSpec(TAG_SIZE, extractedIv);
        SecretKeySpec reconstructedKeySpec = new SecretKeySpec(reconstructedKey, "AES");
        Cipher decipher = Cipher.getInstance("AES/GCM/NoPadding");
        decipher.init(Cipher.DECRYPT_MODE, reconstructedKeySpec, extractedGcmSpec);

        // 执行解密
        byte[] decryptedData = decipher.doFinal(extractedCiphertext);
        String recoveredTreasure = new String(decryptedData);
        System.out.println("🎉 宝物取回成功: " + recoveredTreasure);

        System.out.println("\n=== 步骤6：演示错误的密码会导致失败 ===");
        System.out.println("现在演示如果用错的密码（IV）会发生什么。");

        try {
            // 故意用错误的IV尝试解密
            System.out.println("正在尝试用错误的IV解密...");
            byte[] wrongIv = new byte[IV_SIZE];
            new SecureRandom().nextBytes(wrongIv); // 生成错误的IV
            GCMParameterSpec wrongGcmSpec = new GCMParameterSpec(TAG_SIZE, wrongIv);

            Cipher wrongDecipher = Cipher.getInstance("AES/GCM/NoPadding");
            wrongDecipher.init(Cipher.DECRYPT_MODE, reconstructedKeySpec, wrongGcmSpec);
            wrongDecipher.doFinal(extractedCiphertext); // 使用正确的密文，但错误的IV

            System.out.println("意外：解密竟然成功了？");
        } catch (Exception e) {
            System.out.println("❌ 预期的失败: " + e.getMessage());
            System.out.println("💡 这证明了IV的重要性 - 就像保险箱的密码一样！");
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
