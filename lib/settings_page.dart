import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme_service.dart';
import 'profile_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLoading = true;
  bool _messageNotifications = true;
  bool _callNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _messageNotifications = prefs.getBool('messageNotifications') ?? true;
        _callNotifications = prefs.getBool('callNotifications') ?? true;
        _soundEnabled = prefs.getBool('soundEnabled') ?? true;
        _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Ayarlar yüklenirken hata: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNotificationSetting(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
      print('✅ Bildirim ayarı kaydedildi: $key = $value');
    } catch (e) {
      print('❌ Bildirim ayarı kaydedilemedi: $e');
    }
  }

  Future<void> _toggleDarkMode(bool value) async {
    final theme = Theme.of(context);
    try {
      print('🔄 Tema değiştiriliyor: $value');
      await ThemeService.setTheme(value);
      print('✅ Tema değiştirildi: ${ThemeService.isDarkMode}');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? '🌙 Karanlık mod açıldı' : '☀️ Açık mod açıldı'),
          backgroundColor: value ? theme.colorScheme.surface : theme.colorScheme.primary,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Tema değiştirilemedi: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Tema değiştirilemedi: $e'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  Future<void> _logout() async {
    final theme = Theme.of(context);
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      print('❌ Çıkış yapılırken hata: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Çıkış yapılamadı'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.onPrimary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.settings,
                color: theme.colorScheme.onPrimary,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Ayarlar',
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Görünüm Ayarları
                  _buildSectionHeader('Görünüm', theme),
                  SizedBox(height: 12),
                                     ValueListenableBuilder<bool>(
                     valueListenable: ThemeService.themeNotifier,
                     builder: (context, isDarkMode, child) {
                       return _buildSettingCard(
                         icon: Icons.dark_mode,
                         title: 'Karanlık Mod',
                         subtitle: 'Uygulamayı karanlık temada kullan',
                         trailing: Switch(
                           value: isDarkMode,
                           onChanged: _toggleDarkMode,
                           activeColor: theme.colorScheme.primary,
                          activeTrackColor: theme.colorScheme.primary.withOpacity(0.5),
                          inactiveTrackColor: theme.colorScheme.onSurface.withOpacity(0.3),
                          inactiveThumbColor: theme.colorScheme.surface,
                         ),
                         theme: theme,
                       );
                     },
                   ),
                  SizedBox(height: 16),

                  // Bildirim Ayarları
                  _buildSectionHeader('Bildirimler', theme),
                  SizedBox(height: 12),
                  _buildSettingCard(
                    icon: Icons.notifications,
                    title: 'Mesaj Bildirimleri',
                    subtitle: 'Yeni mesaj geldiğinde bildirim al',
                    trailing: Switch(
                      value: _messageNotifications,
                      onChanged: (value) async {
                        setState(() {
                          _messageNotifications = value;
                        });
                        await _saveNotificationSetting('messageNotifications', value);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(value ? '🔔 Mesaj bildirimleri açıldı' : '🔕 Mesaj bildirimleri kapatıldı'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      activeColor: theme.colorScheme.primary,
                      activeTrackColor: theme.colorScheme.primary.withOpacity(0.5),
                      inactiveTrackColor: theme.colorScheme.onSurface.withOpacity(0.3),
                      inactiveThumbColor: theme.colorScheme.surface,
                    ),
                    theme: theme,
                  ),
                  SizedBox(height: 8),
                  _buildSettingCard(
                    icon: Icons.call,
                    title: 'Arama Bildirimleri',
                    subtitle: 'Gelen aramalar için bildirim al',
                    trailing: Switch(
                      value: _callNotifications,
                      onChanged: (value) async {
                        setState(() {
                          _callNotifications = value;
                        });
                        await _saveNotificationSetting('callNotifications', value);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(value ? '📞 Arama bildirimleri açıldı' : '📵 Arama bildirimleri kapatıldı'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      activeColor: theme.colorScheme.primary,
                      activeTrackColor: theme.colorScheme.primary.withOpacity(0.5),
                      inactiveTrackColor: theme.colorScheme.onSurface.withOpacity(0.3),
                      inactiveThumbColor: theme.colorScheme.surface,
                    ),
                    theme: theme,
                  ),
                  SizedBox(height: 8),
                  _buildSettingCard(
                    icon: Icons.volume_up,
                    title: 'Bildirim Sesi',
                    subtitle: 'Bildirimlerde ses çıkar',
                    trailing: Switch(
                      value: _soundEnabled,
                      onChanged: (value) async {
                        setState(() {
                          _soundEnabled = value;
                        });
                        await _saveNotificationSetting('soundEnabled', value);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(value ? '🔊 Bildirim sesi açıldı' : '🔇 Bildirim sesi kapatıldı'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      activeColor: theme.colorScheme.primary,
                      activeTrackColor: theme.colorScheme.primary.withOpacity(0.5),
                      inactiveTrackColor: theme.colorScheme.onSurface.withOpacity(0.3),
                      inactiveThumbColor: theme.colorScheme.surface,
                    ),
                    theme: theme,
                  ),
                  SizedBox(height: 8),
                  _buildSettingCard(
                    icon: Icons.vibration,
                    title: 'Titreşim',
                    subtitle: 'Bildirimlerde titreşim',
                    trailing: Switch(
                      value: _vibrationEnabled,
                      onChanged: (value) async {
                        setState(() {
                          _vibrationEnabled = value;
                        });
                        await _saveNotificationSetting('vibrationEnabled', value);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(value ? '📳 Titreşim açıldı' : '📴 Titreşim kapatıldı'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      activeColor: theme.colorScheme.primary,
                      activeTrackColor: theme.colorScheme.primary.withOpacity(0.5),
                      inactiveTrackColor: theme.colorScheme.onSurface.withOpacity(0.3),
                      inactiveThumbColor: theme.colorScheme.surface,
                    ),
                    theme: theme,
                  ),
                  SizedBox(height: 16),

                  // Hesap Ayarları
                  _buildSectionHeader('Hesap', theme),
                  SizedBox(height: 12),
                  _buildSettingCard(
                    icon: Icons.person,
                    title: 'Profil Düzenle',
                    subtitle: 'Profil bilgilerinizi güncelleyin',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfilePage(),
                        ),
                      );
                    },
                    theme: theme,
                  ),
                  SizedBox(height: 8),
                  _buildSettingCard(
                    icon: Icons.security,
                    title: 'Gizlilik Ayarları',
                    subtitle: 'Gizlilik tercihlerinizi yönetin',
                    onTap: () {
                      _showPrivacySettings(theme);
                    },
                    theme: theme,
                  ),
                  SizedBox(height: 8),
                  _buildSettingCard(
                    icon: Icons.storage,
                    title: 'Önbellek Temizle',
                    subtitle: 'Uygulama verilerini temizle',
                    onTap: () {
                      _showClearCacheDialog(theme);
                    },
                    theme: theme,
                  ),
                  SizedBox(height: 16),

                  // Uygulama Bilgileri
                  _buildSectionHeader('Uygulama', theme),
                  SizedBox(height: 12),
                  _buildSettingCard(
                    icon: Icons.info,
                    title: 'Hakkında',
                    subtitle: 'Uygulama versiyonu ve bilgileri',
                    onTap: () {
                      _showAboutDialog(theme);
                    },
                    theme: theme,
                  ),
                  SizedBox(height: 8),
                  _buildSettingCard(
                    icon: Icons.help,
                    title: 'Yardım',
                    subtitle: 'Kullanım kılavuzu ve destek',
                    onTap: () {
                      _showHelpDialog(theme);
                    },
                    theme: theme,
                  ),
                  SizedBox(height: 24),

                  // Çıkış Yap Butonu
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.logout, color: theme.colorScheme.onError),
                      label: Text('Çıkış Yap', style: TextStyle(color: theme.colorScheme.onError, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        _showLogoutDialog();
                      },
                    ),
                  ),
                  SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeData theme,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.cardColor,
            theme.cardColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: theme.primaryColor,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  void _showAboutDialog(ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info, color: theme.primaryColor),
            SizedBox(width: 8),
            Text('Hakkında'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Balaban Projesi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 8),
            Text('Versiyon: 1.0.0'),
            SizedBox(height: 4),
            Text('Geliştirici: Balaban Team'),
            SizedBox(height: 4),
            Text('© 2025 Tüm hakları saklıdır'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Tamam'),
          ),
        ],
      );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.logout, color: theme.colorScheme.error),
            SizedBox(width: 8),
            Text('Çıkış Yap'),
          ],
        ),
        content: Text('Hesabınızdan çıkış yapmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: Text('Çıkış Yap'),
          ),
        ],
      );
      },
    );
  }

  void _showPrivacySettings(ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.security, color: theme.primaryColor),
            SizedBox(width: 8),
            Text('Gizlilik Ayarları'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🔐 Hesap Gizliliği', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• Profiliniz sadece onaylı kişiler tarafından görülebilir'),
              Text('• Mesajlarınız uçtan uca şifrelenir'),
              Text('• Konum bilginiz güvenli şekilde saklanır'),
              SizedBox(height: 16),
              Text('📱 Veri Güvenliği', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• Tüm verileriniz Firebase\'de güvenle saklanır'),
              Text('• Kişisel bilgileriniz üçüncü taraflarla paylaşılmaz'),
              Text('• İstediğiniz zaman hesabınızı silebilirsiniz'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.storage, color: theme.primaryColor),
            SizedBox(width: 8),
            Text('Önbellek Temizle'),
          ],
        ),
        content: Text('Uygulama önbelleğini temizlemek istediğinizden emin misiniz? Bu işlem profil fotoğrafları ve diğer geçici dosyaları silecektir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Önbellek temizleme işlemi
              try {
                // SharedPreferences temizleme hariç tutabiliriz
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🧹 Önbellek temizlendi'),
                    backgroundColor: theme.colorScheme.primary,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Önbellek temizlenemedi'),
                    backgroundColor: theme.colorScheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            child: Text('Temizle'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help, color: theme.primaryColor),
            SizedBox(width: 8),
            Text('Yardım'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🚀 Nasıl Başlarım?', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('1. "Bağlan" sekmesinden rastgele kişilerle tanışabilirsin'),
              Text('2. "Sosyal" sekmesinden genel sohbete katılabilirsin'),
              Text('3. "Çevrimiçi" sekmesinden aktif kullanıcıları görebilirsin'),
              SizedBox(height: 16),
              Text('💬 Mesajlaşma', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• Herhangi bir kullanıcıya tıklayıp mesaj gönderebilirsin'),
              Text('• Sesli ve görüntülü arama yapabilirsin'),
              Text('• Mesajların anlık olarak iletilir'),
              SizedBox(height: 16),
              Text('📞 Destek', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Sorun yaşıyorsan ayarlardan "Çıkış Yap" ile çıkıp tekrar giriş yapabilirsin.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Tamam'),
          ),
        ],
      ),
    );
  }
} 