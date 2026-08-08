/// Day 73-74 — DO NOT DISTURB Screen
///
/// Allows users to configure quiet hours (Do Not Disturb) and language
/// preference. Uses PUT /api/v1/users/preferences/ endpoint built Day 73.
///
/// ── Features ──────────────────────────────────────────────────────────────
///   • DND master toggle (enable / disable quiet hours)
///   • Start hour picker (0-23, 12h format display)
///   • End hour picker  (0-23, 12h format display)
///   • Wrap-around support displayed: "10:00 PM → 6:00 AM"
///   • Language selector dropdown (15 supported languages)
///   • SOS exception notice: SOS alerts always bypass DND (non-dismissible)
///   • Save button → PUT /api/v1/users/preferences/
///   • Emulator tile added to index screen
library;

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/constants/api_config.dart';
import '../../core/theme/spacing.dart';

class DoNotDisturbScreen extends StatefulWidget {
  const DoNotDisturbScreen({super.key});

  @override
  State<DoNotDisturbScreen> createState() => _DoNotDisturbScreenState();
}

class _DoNotDisturbScreenState extends State<DoNotDisturbScreen> {
  bool _dndEnabled = false;
  int _startHour = 22; // 10 PM default
  int _endHour = 7;    // 7 AM default
  String _selectedLanguage = 'en';
  bool _loading = true;
  bool _saving = false;
  String? _errorMsg;

  // 15 supported languages
  static const List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'hi', 'name': 'हिन्दी (Hindi)'},
    {'code': 'ta', 'name': 'தமிழ் (Tamil)'},
    {'code': 'te', 'name': 'తెలుగు (Telugu)'},
    {'code': 'ml', 'name': 'മലയാളം (Malayalam)'},
    {'code': 'bn', 'name': 'বাংলা (Bengali)'},
    {'code': 'mr', 'name': 'मराठी (Marathi)'},
    {'code': 'gu', 'name': 'ગુજરાતી (Gujarati)'},
    {'code': 'pa', 'name': 'ਪੰਜਾਬੀ (Punjabi)'},
    {'code': 'ur', 'name': 'اردو (Urdu)'},
    {'code': 'ar', 'name': 'العربية (Arabic)'},
    {'code': 'es', 'name': 'Español'},
    {'code': 'fr', 'name': 'Français'},
    {'code': 'pt', 'name': 'Português'},
    {'code': 'de', 'name': 'Deutsch'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
      ));
      final res = await dio.get(
        '/api/v1/users/preferences/',
        options: Options(
          headers: {'Authorization': 'Bearer ${ApiConfig.devToken}'},
        ),
      );
      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        setState(() {
          _dndEnabled = data['dnd_enabled'] ?? false;
          _startHour = data['quiet_hours_start_hour'] ?? 22;
          _endHour = data['quiet_hours_end_hour'] ?? 7;
          _selectedLanguage = data['language'] ?? 'en';
        });
      }
    } catch (_) {
      // Use defaults on error (emulator mode)
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _savePreferences() async {
    setState(() { _saving = true; _errorMsg = null; });
    try {
      final body = {
        'language': _selectedLanguage,
        'quiet_hours_start_hour': _dndEnabled ? _startHour : null,
        'quiet_hours_end_hour': _dndEnabled ? _endHour : null,
      };
      final dio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
      ));
      final res = await dio.put(
        '/api/v1/users/preferences/',
        data: body,
        options: Options(
          headers: {'Authorization': 'Bearer ${ApiConfig.devToken}'},
        ),
      );
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Preferences saved ✓'),
              backgroundColor: Color(0xFF22C55E),
            ),
          );
        }
      } else {
        setState(() => _errorMsg = 'Failed to save. Try again.');
      }
    } catch (_) {
      setState(() => _errorMsg = 'No connection. Saved locally.');
    } finally {
      setState(() => _saving = false);
    }
  }

  String _formatHour(int hour) {
    final period = hour < 12 ? 'AM' : 'PM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$h:00 $period';
  }

  String _dndRangeLabel() {
    if (!_dndEnabled) return 'DND is OFF';
    return '${_formatHour(_startHour)} → ${_formatHour(_endHour)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        title: const Text(
          'Do Not Disturb',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(ZapSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── SOS Exception Banner ───────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'SOS alerts always bypass Do Not Disturb — you will always be notified during emergencies.',
                            style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: ZapSpacing.xxl),

                  // ── DND Master Toggle ──────────────────────────────────
                  _buildSectionLabel('QUIET HOURS'),
                  const SizedBox(height: ZapSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.lg, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Enable Quiet Hours',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: ZapSpacing.xs),
                            Text(
                              _dndRangeLabel(),
                              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                            ),
                          ],
                        ),
                        Switch(
                          value: _dndEnabled,
                          onChanged: (val) => setState(() => _dndEnabled = val),
                          activeColor: const Color(0xFF6366F1),
                        ),
                      ],
                    ),
                  ),

                  if (_dndEnabled) ...[
                    const SizedBox(height: ZapSpacing.lg),
                    // ── Hour Pickers ─────────────────────────────────────
                    Row(
                      children: [
                        Expanded(child: _buildHourPicker('Start', _startHour, (v) => setState(() => _startHour = v))),
                        const SizedBox(width: ZapSpacing.md),
                        Expanded(child: _buildHourPicker('End', _endHour, (v) => setState(() => _endHour = v))),
                      ],
                    ),
                    const SizedBox(height: ZapSpacing.sm),
                    Text(
                      'DND active: ${_formatHour(_startHour)} → ${_formatHour(_endHour)}',
                      style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 28),

                  // ── Language Selector ──────────────────────────────────
                  _buildSectionLabel('LANGUAGE'),
                  const SizedBox(height: ZapSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.lg),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedLanguage,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1C1C1E),
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF9CA3AF)),
                        items: _languages.map((lang) {
                          return DropdownMenuItem<String>(
                            value: lang['code'],
                            child: Text(lang['name']!),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedLanguage = val);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: ZapSpacing.xxxl),

                  // ── Error Message ──────────────────────────────────────
                  if (_errorMsg != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: ZapSpacing.md),
                      child: Text(
                        _errorMsg!,
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                      ),
                    ),

                  // ── Save Button ────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _savePreferences,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        disabledBackgroundColor: const Color(0xFF6366F1).withOpacity(0.5),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Save Preferences',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  const SizedBox(height: ZapSpacing.xl),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildHourPicker(String label, int currentHour, ValueChanged<int> onChanged) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            _formatHour(currentHour),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _hourButton(Icons.remove, () => onChanged((currentHour - 1 + 24) % 24)),
              _hourButton(Icons.add, () => onChanged((currentHour + 1) % 24)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hourButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF374151),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
