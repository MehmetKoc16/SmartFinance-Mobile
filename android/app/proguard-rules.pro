# google_mlkit_text_recognition eklentisi bes yazi sisteminin hepsine kodda
# atif yapiyor, ama uygulamaya yalnizca Latin modeli ekleniyor (Turkce icin
# yeterli; digerleri APK'ya model basina birkac MB ekler). Eksik siniflar
# bilerek eksik: kod bu yollara hic girmiyor (script: latin sabit).
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit'in Play Hizmetleri surumu bilesenlerini yansima (reflection) ile
# yukluyor; R8 bunlari kullanilmiyor sanip siliyordu. Belirti (26.09.2026,
# cihazda): TextRecognizer ilk goruntude NullPointerException veriyordu
# (mlkit_vision_common.zzmj.<init>, "getClass() on a null object").
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_** { *; }
