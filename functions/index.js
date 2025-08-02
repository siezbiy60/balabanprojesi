const functions = require("firebase-functions");
const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

// Region'ı belirt
const region = 'europe-west1';

exports.sendPushNotificationHttp = functions.region(region).https.onRequest(async (req, res) => {
  // CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  
  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  
  let token, title, body, data;
  if (req.method === "POST") {
    token = req.body.token;
    title = req.body.title;
    body = req.body.body;
    data = req.body.data || {};
  } else {
    token = req.query.token;
    title = req.query.title;
    body = req.query.body;
    data = req.query.data || {};
  }

  console.log('📱 Cloud Function çağrıldı:', { token: token ? token.substring(0, 20) + '...' : 'null', title, body, data });

  // Data'yı string'e çevir (FCM requirement)
  const stringifiedData = {};
  if (data && typeof data === 'object') {
    Object.keys(data).forEach(key => {
      stringifiedData[key] = String(data[key]);
    });
  }

  // Mesaj tipine göre farklı konfigürasyon
  let message;
  
  if (stringifiedData.type === 'message') {
    // Mesaj bildirimleri için data-only (arka plan için)
    message = {
      token: token,
      data: {
        ...stringifiedData,
        title: title || "Yeni Mesaj",
        body: body || "Mesaj geldi",
      },
      android: {
        priority: 'high',
        data: {
          ...stringifiedData,
          title: title || "Yeni Mesaj",
          body: body || "Mesaj geldi",
        },
      },
      apns: {
        payload: {
          aps: {
            'content-available': 1,
            alert: {
              title: title || "Yeni Mesaj",
              body: body || "Mesaj geldi",
            },
            sound: 'default',
            badge: 1,
          },
          data: stringifiedData,
        },
      },
    };
  } else {
    // Test bildirimleri için normal notification
    message = {
      token: token,
      notification: {
        title: title || "Test Bildirimi",
        body: body || "Bu bir test mesajıdır!",
      },
      data: stringifiedData,
      android: {
        priority: 'high',
        notification: {
          channel_id: 'messages',
          priority: 'high',
          default_sound: true,
          default_vibrate_timings: true,
          visibility: 'public',
          icon: 'ic_launcher',
          color: '#1976D2',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            'content-available': 1,
          },
        },
      },
      webpush: {
        headers: {
          Urgency: 'high',
        },
      },
    };
  }

  if (token) {
    try {
      console.log('📱 FCM mesajı gönderiliyor:', message);
      const response = await admin.messaging().send(message);
      console.log('✅ FCM başarılı:', response);
      res.status(200).send("Bildirim gönderildi!");
    } catch (e) {
      console.error("❌ Bildirim gönderilemedi:", e);
      res.status(500).send("Bildirim gönderilemedi: " + e.message);
    }
  } else {
    console.error("❌ Token eksik!");
    res.status(400).send("Token eksik!");
  }
});

exports.sendPushNotification = functions.region(region).firestore
  .document("notifications/{notificationId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const token = data.token;
    const message = {
      token: token,
      notification: {
        title: data.title,
        body: data.body,
      },
    };
    if (token) {
      try {
        await admin.messaging().send(message);
        console.log("Firestore bildirimi gönderildi:", token, message);
      } catch (e) {
        console.error("Firestore bildirimi gönderilemedi:", e);
      }
    } else {
      console.log("Token yok, bildirim gönderilmedi.");
    }
    return null;
  });