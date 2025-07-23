// [START initialize_firebase_in_sw]
// Give the service worker access to Firebase Messaging.
// Note that you can only use Firebase Messaging here, other Firebase libraries are not available in the service worker.
importScripts('https://www.gstatic.com/firebasejs/9.6.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.6.1/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker by passing in the messagingSenderId.
firebase.initializeApp({
  apiKey: "AIzaSyBvAlKYTRaD_wDZlIiafc9Rv9aA2oK0sGo",
  authDomain: "balabanproje.firebaseapp.com",
  projectId: "balabanproje",
  storageBucket: "balabanproje.appspot.com",
  messagingSenderId: "914532151784",
  appId: "1:914532151784:web:f9a030d8c7ae1a3c65f45d",
  measurementId: "G-22M35XW0FV"
});

// Retrieve an instance of Firebase Messaging so that it can handle background messages.
const messaging = firebase.messaging();
// [END initialize_firebase_in_sw] 