import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Ayarlar yüklenirken hata: $e');
      setState(() => _isLoading = false);
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
                      value: true,
                      onChanged: (value) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('🔔 Bildirim ayarları yakında eklenecek')),
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
                      value: true,
                      onChanged: (value) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('📞 Arama bildirimleri yakında eklenecek')),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('👤 Profil düzenleme yakında eklenecek')),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('🔐 Gizlilik ayarları yakında eklenecek')),
                      );
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('❓ Yardım sayfası yakında eklenecek')),
                      );
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
} 