import 'package:flutter/material.dart';
import 'package:farmigrow_ai/theme/app_theme.dart';
import 'package:farmigrow_ai/models/farm_model.dart';
import 'package:farmigrow_ai/services/farm_storage.dart';
import 'package:farmigrow_ai/services/user_profile_storage.dart';
import 'package:farmigrow_ai/services/notification_service.dart';
import 'package:farmigrow_ai/services/api_service.dart';
import 'package:farmigrow_ai/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Farm> _userFarms = [];
  bool _loading = true;
  bool _editing = false;
  bool _alertsEnabled = true;
  bool _savingProfile = false;
  bool? _backendOnline; // null = checking, true/false = result

  late UserProfile _profile;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  String _role = 'Farmer';

  @override
  void initState() {
    super.initState();
    _load();
    _checkBackendStatus();
  }

  Future<void> _checkBackendStatus() async {
    final online = await ApiService.isBackendReachable();
    if (mounted) setState(() => _backendOnline = online);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final farms = await FarmStorage.getUserFarms();
    final profile = await UserProfileStorage.getProfile();
    final alertsOn = await NotificationService.isEnabled();
    setState(() {
      _userFarms = farms;
      _profile = profile;
      _nameController.text = profile.name;
      _phoneController.text = profile.phone;
      _locationController.text = profile.location;
      _role = profile.role;
      _alertsEnabled = alertsOn;
      _loading = false;
    });

    // Background cloud sync — refresh again only if something changed,
    // so editing isn't disrupted mid-type.
    final syncedFarms = await FarmStorage.syncFromCloud();
    if (mounted && syncedFarms.length != farms.length) {
      setState(() => _userFarms = syncedFarms);
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please enter your name')),
      );
      return;
    }
    if (_phoneController.text.trim().isNotEmpty &&
        _phoneController.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please enter a valid 10-digit phone number')),
      );
      return;
    }

    setState(() => _savingProfile = true);
    final updated = UserProfile(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      location: _locationController.text.trim(),
      role: _role,
    );
    await UserProfileStorage.saveProfile(updated);
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      _profile = updated;
      _editing = false;
      _savingProfile = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Profile updated successfully!'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    }
  }

  Future<void> _toggleAlerts(bool value) async {
    setState(() => _alertsEnabled = value);
    await NotificationService.setEnabled(value);
    if (value) {
      await NotificationService.sendTestNotification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_profile.phone.isNotEmpty
                ? '🔔 Alerts enabled. Notifications will be sent to this phone for ${_profile.phone}.'
                : '🔔 Alerts enabled on this phone.'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🔕 Alerts disabled.')),
        );
      }
    }
  }

  Widget _buildSyncBadge() {
    if (_backendOnline == null) {
      return const SizedBox(
        width: 12, height: 12,
        child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.textGrey),
      );
    }
    final online = _backendOnline!;
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(online
                ? '☁️ Connected — your farms sync to the cloud automatically.'
                : '📴 Offline — changes save on this phone and will sync once you\'re back online.'),
            backgroundColor: online ? AppTheme.primaryGreen : AppTheme.amber,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: (online ? AppTheme.primaryGreen : AppTheme.amber).withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(online ? Icons.cloud_done : Icons.cloud_off,
                size: 12, color: online ? AppTheme.primaryGreen : AppTheme.amber),
            const SizedBox(width: 3),
            Text(online ? 'Synced' : 'Offline',
                style: AppTheme.caption().copyWith(
                    color: online ? AppTheme.primaryGreen : AppTheme.amber,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
      );
    }

    final totalFarms = _userFarms.length;
    final totalAcres = _userFarms.fold<double>(0, (sum, f) => sum + f.areaAcres);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        title: Row(
          children: [
            Text('Account', style: AppTheme.h1()),
            const SizedBox(width: AppTheme.spaceSM),
            _buildSyncBadge(),
          ],
        ),
        actions: [
          if (!_editing)
            TextButton.icon(
              onPressed: () => setState(() => _editing = true),
              icon: const Icon(Icons.edit, size: 16, color: AppTheme.primaryGreen),
              label: Text('Edit', style: AppTheme.body().copyWith(color: AppTheme.primaryGreen)),
            )
          else
            TextButton(
              onPressed: () {
                setState(() {
                  _editing = false;
                  _nameController.text = _profile.name;
                  _phoneController.text = _profile.phone;
                  _locationController.text = _profile.location;
                  _role = _profile.role;
                });
              },
              child: Text('Cancel', style: AppTheme.body().copyWith(color: AppTheme.textGrey)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account header card - view or edit mode
            Container(
              padding: AppTheme.cardPadding,
              decoration: AppTheme.cardDecoration(),
              child: _editing ? _buildEditForm() : _buildViewProfile(),
            ),
            const SizedBox(height: AppTheme.spaceLG),

            if (!_editing) ...[
              // Stats row
              Row(
                children: [
                  Expanded(child: _statCard(Icons.agriculture, '$totalFarms', 'Total Farms', AppTheme.primaryGreen)),
                  const SizedBox(width: AppTheme.spaceSM),
                  Expanded(child: _statCard(Icons.crop_square, totalAcres.toStringAsFixed(1), 'Total Acres', AppTheme.accentBlue)),
                  const SizedBox(width: AppTheme.spaceSM),
                  Expanded(child: _statCard(Icons.water, '0', 'Aqua Ponds', Colors.cyan)),
                ],
              ),
              const SizedBox(height: AppTheme.spaceXL),

              // Alerts toggle
              Text('ALERTS & NOTIFICATIONS', style: AppTheme.label()),
              const SizedBox(height: AppTheme.spaceMD),
              Container(
                padding: AppTheme.cardPaddingSmall,
                decoration: AppTheme.cardDecoration(),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: AppTheme.iconBoxMD, height: AppTheme.iconBoxMD,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                          ),
                          child: const Icon(Icons.notifications_active, color: AppTheme.primaryGreen, size: 20),
                        ),
                        const SizedBox(width: AppTheme.spaceMD),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Phone Alerts', style: AppTheme.h3()),
                              Text(
                                _profile.phone.isNotEmpty
                                    ? 'Sent to ${_profile.phone}'
                                    : 'Add a phone number to receive SMS alerts',
                                style: AppTheme.caption(),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _alertsEnabled,
                          activeColor: AppTheme.primaryGreen,
                          onChanged: _toggleAlerts,
                        ),
                      ],
                    ),
                    if (_alertsEnabled) ...[
                      const Divider(color: AppTheme.borderColor, height: 20),
                      Row(
                        children: [
                          const Icon(Icons.phone_android, color: AppTheme.textGrey, size: 16),
                          const SizedBox(width: AppTheme.spaceSM),
                          Expanded(
                            child: Text('Push notifications enabled on this device',
                                style: AppTheme.bodySmall()),
                          ),
                          TextButton(
                            onPressed: () => NotificationService.sendTestNotification(),
                            child: Text('Test', style: AppTheme.bodySmall().copyWith(color: AppTheme.primaryGreen)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceXL),

              Text('MY FARMS', style: AppTheme.label()),
              const SizedBox(height: AppTheme.spaceMD),
              if (_userFarms.isEmpty)
                Container(
                  padding: AppTheme.cardPadding,
                  decoration: AppTheme.cardDecoration(),
                  child: Text(
                      'You haven\'t added any farms yet. Use "Draw New Farm Boundary" on the Satellite tab to add one.',
                      style: AppTheme.bodySmall()),
                )
              else
                ..._userFarms.map((f) => Container(
                      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
                      padding: AppTheme.cardPaddingSmall,
                      decoration: AppTheme.cardDecoration(),
                      child: Row(
                        children: [
                          const Icon(Icons.agriculture, color: AppTheme.primaryGreen, size: 18),
                          const SizedBox(width: AppTheme.spaceMD),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f.name, style: AppTheme.h3()),
                                Text('${f.cropType} · ${f.areaAcres} acres', style: AppTheme.caption()),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.dangerRed, size: 18),
                            onPressed: () async {
                              await FarmStorage.deleteFarm(f.id);
                              _load();
                            },
                          ),
                        ],
                      ),
                    )),

              const SizedBox(height: AppTheme.spaceXL),
              Text('SETTINGS', style: AppTheme.label()),
              const SizedBox(height: AppTheme.spaceMD),
              _settingsTile(Icons.language, 'Language', 'English / తెలుగు'),
              _settingsTile(Icons.cloud_outlined, 'Satellite Source', 'Sentinel-2, MODIS'),
              _settingsTile(Icons.info_outline, 'About FarmiGrow AI', 'v1.0 · Phase A'),
              const SizedBox(height: AppTheme.spaceMD),
              GestureDetector(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: AppTheme.bgCard,
                      title: Text('Sign Out', style: AppTheme.h2()),
                      content: Text('Are you sure you want to sign out?',
                          style: AppTheme.body()),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('Cancel', style: AppTheme.body().copyWith(color: AppTheme.textGrey)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text('Sign Out', style: AppTheme.body().copyWith(color: AppTheme.dangerRed)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    await AuthService.signOut();
                    if (mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/',
                        (route) => false,
                      );
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMD, vertical: AppTheme.spaceMD),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(color: AppTheme.dangerRed.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout, color: AppTheme.dangerRed, size: 18),
                      const SizedBox(width: AppTheme.spaceSM),
                      Text('Sign Out', style: AppTheme.body().copyWith(color: AppTheme.dangerRed, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spaceXXL),
              Center(
                child: Text('FarmiGrow AI · Satellite-Powered Farm Intelligence',
                    style: AppTheme.caption()),
              ),
            ],
            const SizedBox(height: AppTheme.spaceXL),
          ],
        ),
      ),
    );
  }

  Widget _buildViewProfile() {
    return Row(
      children: [
        CircleAvatar(
          radius: AppTheme.avatarMD,
          backgroundColor: AppTheme.primaryGreen.withOpacity(0.15),
          child: const Icon(Icons.person, size: 40, color: AppTheme.primaryGreen),
        ),
        const SizedBox(width: AppTheme.spaceLG),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(_profile.name, style: AppTheme.h1().copyWith(fontSize: 18)),
                  const SizedBox(width: AppTheme.spaceSM),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_profile.role,
                        style: AppTheme.caption().copyWith(color: AppTheme.accentBlue, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (_profile.phone.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.phone, size: 12, color: AppTheme.textGrey),
                    const SizedBox(width: 4),
                    Text(_profile.phone, style: AppTheme.bodySmall()),
                  ],
                ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 12, color: AppTheme.textGrey),
                  const SizedBox(width: 3),
                  Expanded(child: Text(_profile.location, style: AppTheme.bodySmall())),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Edit Profile', style: AppTheme.h2()),
        const SizedBox(height: AppTheme.spaceLG),

        Text('Account Type', style: AppTheme.bodySmall().copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppTheme.spaceSM),
        Row(
          children: [
            Expanded(child: _roleChip('Farmer', Icons.agriculture)),
            const SizedBox(width: AppTheme.spaceSM),
            Expanded(child: _roleChip('Customer', Icons.shopping_bag)),
          ],
        ),
        const SizedBox(height: AppTheme.spaceLG),

        _buildTextField(_nameController, 'Full Name', Icons.person, TextInputType.name),
        const SizedBox(height: AppTheme.spaceMD),
        _buildTextField(_phoneController, 'Phone Number (for alerts)', Icons.phone, TextInputType.phone, maxLength: 10),
        const SizedBox(height: AppTheme.spaceMD),
        _buildTextField(_locationController, 'Location', Icons.location_on, TextInputType.text),
        const SizedBox(height: AppTheme.spaceLG),

        SizedBox(
          width: double.infinity,
          height: AppTheme.buttonHeight,
          child: ElevatedButton(
            onPressed: _savingProfile ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
            ),
            child: _savingProfile
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : Text('Save Changes', style: AppTheme.button()),
          ),
        ),
      ],
    );
  }

  Widget _roleChip(String role, IconData icon) {
    final selected = _role == role;
    return GestureDetector(
      onTap: () => setState(() => _role = role),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMD),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryGreen.withOpacity(0.15) : AppTheme.bgCardLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: selected ? AppTheme.primaryGreen : AppTheme.borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppTheme.primaryGreen : AppTheme.textGrey, size: 22),
            const SizedBox(height: 4),
            Text(role, style: AppTheme.bodySmall().copyWith(
                color: selected ? AppTheme.primaryGreen : AppTheme.textGrey,
                fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, TextInputType keyboardType, {int? maxLength}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: AppTheme.body().copyWith(color: AppTheme.textWhite),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTheme.bodySmall(),
        prefixIcon: Icon(icon, color: AppTheme.primaryGreen, size: 20),
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          borderSide: const BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          borderSide: const BorderSide(color: AppTheme.primaryGreen),
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMD),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: AppTheme.statValue()),
          Text(label, style: AppTheme.caption()),
        ],
      ),
    );
  }

  Widget _settingsTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMD, vertical: AppTheme.spaceMD),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryGreen, size: 18),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(child: Text(title, style: AppTheme.body().copyWith(color: AppTheme.textWhite))),
          Text(value, style: AppTheme.bodySmall()),
        ],
      ),
    );
  }
}
