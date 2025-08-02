# BalabanProje - Basit Sesli Arama Sistemi

Bu proje, Firebase Firestore kullanarak basit bir sesli arama sistemi içeren Flutter uygulamasıdır. Sistem, Agora gibi karmaşık WebRTC servisleri kullanmadan, sadece Firestore signaling ve push notification ile çalışır.

## 🚀 Özellikler

- **Basit Sesli Arama**: Firestore tabanlı signaling sistemi
- **Push Bildirimleri**: Gelen aramalar için Firebase Cloud Messaging
- **Gerçek Zamanlı Durum**: Arama durumları gerçek zamanlı olarak güncellenir
- **Kullanıcı Dostu Arayüz**: Modern ve kullanımı kolay arayüz
- **Güvenli**: Firebase Authentication ile korumalı

## 📱 Arama Sistemi Nasıl Çalışır

### 1. Arama Başlatma
- Kullanıcı chat sayfasında arama butonuna basar
- `SimpleCallService.startCall()` çağrılır
- Firestore'da yeni bir `calls` belgesi oluşturulur
- Karşı tarafa push notification gönderilir

### 2. Gelen Arama
- Alıcı push notification alır
- Uygulama açıksa overlay gösterilir
- Alıcı aramayı kabul edebilir veya reddedebilir

### 3. Arama Durumları
- `ringing`: Arama çalıyor
- `accepted`: Arama kabul edildi
- `rejected`: Arama reddedildi
- `ended`: Arama sonlandı

### 4. Arama Sonlandırma
- Her iki taraf da aramayı sonlandırabilir
- Firestore'da durum `ended` olarak güncellenir
- CallPage otomatik olarak kapanır

## 🛠️ Teknik Detaylar

### Firestore Koleksiyonları

#### `calls` Koleksiyonu
```json
{
  "callId": "unique_call_id",
  "callerId": "caller_user_id",
  "receiverId": "receiver_user_id",
  "status": "ringing|accepted|rejected|ended",
  "timestamp": "server_timestamp",
  "callerName": "caller_name",
  "acceptedAt": "server_timestamp",
  "rejectedAt": "server_timestamp",
  "endedAt": "server_timestamp",
  "endedBy": "user_id"
}
```

#### `users` Koleksiyonu
```json
{
  "userId": "user_id",
  "username": "user_name",
  "fcmToken": "firebase_messaging_token",
  "email": "user_email"
}
```

### Güvenlik Kuralları

Firestore güvenlik kuralları, sadece arama ile ilgili kullanıcıların verilere erişmesine izin verir:

```javascript
match /calls/{callId} {
  allow read, write: if request.auth != null &&
    (request.auth.uid == resource.data.callerId || 
     request.auth.uid == resource.data.receiverId);
  
  allow create: if request.auth != null &&
    request.auth.uid == request.resource.data.callerId;
}
```

## 📦 Kurulum

### Gereksinimler
- Flutter SDK 3.4.0+
- Firebase projesi
- Android Studio / VS Code

### Adımlar

1. **Projeyi klonlayın**
   ```bash
   git clone <repository_url>
   cd balabanprojesi
   ```

2. **Bağımlılıkları yükleyin**
   ```bash
   flutter pub get
   ```

3. **Firebase yapılandırması**
   - Firebase Console'da yeni proje oluşturun
   - `google-services.json` dosyasını `android/app/` klasörüne ekleyin
   - `GoogleService-Info.plist` dosyasını `ios/Runner/` klasörüne ekleyin

4. **Cloud Functions'ı deploy edin**
   ```bash
   cd functions
   npm install
   firebase deploy --only functions
   ```

5. **Uygulamayı çalıştırın**
   ```bash
   flutter run
   ```

## 🔧 Yapılandırma

### Firebase Cloud Functions

`functions/index.js` dosyasında push notification gönderme fonksiyonu bulunur:

```javascript
exports.sendPushNotificationHttp = functions.https.onRequest(async (req, res) => {
  // Push notification gönderme mantığı
});
```

### Android İzinleri

`android/app/src/main/AndroidManifest.xml` dosyasına aşağıdaki izinleri ekleyin:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

## 📱 Kullanım

1. **Giriş Yapın**: Uygulamaya giriş yapın
2. **Arkadaş Bulun**: Ana sayfada arkadaşlarınızı görün
3. **Chat Açın**: Arkadaşınızla sohbet sayfasını açın
4. **Arama Yapın**: Telefon ikonuna basarak arama başlatın
5. **Aramayı Kabul Edin**: Gelen aramaları kabul edin veya reddedin

## 🐛 Sorun Giderme

### Yaygın Sorunlar

1. **Push notification gelmiyor**
   - FCM token'ın doğru kaydedildiğinden emin olun
   - Cloud Functions'ın deploy edildiğini kontrol edin

2. **Arama başlatılamıyor**
   - Mikrofon izninin verildiğinden emin olun
   - Firestore kurallarını kontrol edin

3. **Arama durumu güncellenmiyor**
   - İnternet bağlantısını kontrol edin
   - Firestore bağlantısını test edin

## 📄 Lisans

Bu proje MIT lisansı altında lisanslanmıştır.

## 🤝 Katkıda Bulunma

1. Fork yapın
2. Feature branch oluşturun (`git checkout -b feature/amazing-feature`)
3. Commit yapın (`git commit -m 'Add amazing feature'`)
4. Push yapın (`git push origin feature/amazing-feature`)
5. Pull Request oluşturun

## 📞 İletişim

Sorularınız için issue açabilir veya iletişime geçebilirsiniz.
