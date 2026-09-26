# google_mlkit_text_recognition eklentisi bes yazi sisteminin hepsine kodda
# atif yapiyor, ama uygulamaya yalnizca Latin modeli ekleniyor (Turkce icin
# yeterli; digerleri APK'ya model basina birkac MB ekler). Eksik siniflar
# bilerek eksik: kod bu yollara hic girmiyor (script: latin sabit).
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
