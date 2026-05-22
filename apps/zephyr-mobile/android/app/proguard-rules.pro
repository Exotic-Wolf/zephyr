# Agora Chat SDK — keep native bridge classes
-keep class com.hyphenate.** {*;}
-dontwarn com.hyphenate.**

# Agora Chat SDK references Chinese push SDKs we don't use
-dontwarn com.vivo.push.**
-dontwarn com.xiaomi.mipush.**
-dontwarn com.huawei.hms.**
-dontwarn com.meizu.cloud.**
-dontwarn com.heytap.msp.**
-dontwarn com.hihonor.push.**
