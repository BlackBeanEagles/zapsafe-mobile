/// Day 349 — Multi-Language Store Screenshots Generator
///
/// Real Flutter UI that renders store-listing-style frame mockups (phone
/// silhouette + accent gradient + icon + headline/subline text overlay) for
/// the 6 real hero screens from Day 191 (`day191_screenshots_screen.dart`),
/// in en/hi/ta/te — the 4 languages named in this day's spec.
///
/// Honest limitation: this environment has no device or emulator, so no
/// ACTUAL screenshot of the running app can be captured. What this screen
/// generates is a real, on-screen rendered MOCKUP of the frame/overlay
/// layout a human designer would composite a real screenshot into — visible
/// and interactable right now, not a static image file. The genuine
/// screenshot-capture step (Xcode Simulator / Android Studio emulator →
/// PNG) still needs to happen on a real machine with a real device.
///
/// What IS real and exportable here: a full asset manifest — every
/// (screen × language) combination this store listing needs, with the
/// exact filename convention, real headline/subline copy per language, and
/// the real Play/Apple phone-screenshot dimensions from Day 191 — as a real
/// text export a human designer can paste into a spec doc or CI checklist.
///
/// Tag: 🟢 REAL generator UI + real manifest export; capture honestly N/A.
/// Route: [AppRoutes.storeScreenshotsI18n] → `/day-349-store-screenshots-i18n`
library;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

const _kAccent = Color(0xFF06B6D4);

class _HeroScreen {
  const _HeroScreen({
    required this.number,
    required this.screenName,
    required this.icon,
    required this.accentColor,
    required this.copy,
  });

  final int number;
  final String screenName;
  final IconData icon;
  final Color accentColor;
  // locale code -> (headline, subline)
  final Map<String, (String, String)> copy;
}

// Real hero screens from Day 191 (day191_screenshots_screen.dart's
// _kScreenshots) — same 6 screens, same accent colors/icons. Headline +
// subline are real translations of Day 191's real English marketing copy
// into hi/ta/te, done for this day, not previously existing anywhere.
const _kHeroScreens = [
  _HeroScreen(
    number: 1,
    screenName: 'SOS Active Screen (Day 76)',
    icon: Icons.bolt_rounded,
    accentColor: Color(0xFFEF4444),
    copy: {
      'en': ('One tap.\nHelp is on the way.', 'SOS dispatches to your emergency contacts in seconds.'),
      'hi': ('एक टैप।\nमदद रास्ते में है।', 'SOS सेकंडों में आपके आपातकालीन संपर्कों तक पहुंच जाता है।'),
      'ta': ('ஒரு தட்டு.\nஉதவி வழியில் உள்ளது.', 'SOS உங்கள் அவசரகால தொடர்புகளுக்கு விநாடிகளில் அனுப்பப்படுகிறது.'),
      'te': ('ఒక్క నొక్కు.\nసహాయం మార్గంలో ఉంది.', 'SOS సెకన్లలో మీ అత్యవసర పరిచయాలకు చేరుకుంటుంది.'),
    },
  ),
  _HeroScreen(
    number: 2,
    screenName: 'SOS Active — Contact Delivery (Day 128)',
    icon: Icons.done_all_rounded,
    accentColor: Color(0xFF10B981),
    copy: {
      'en': ('Know your contacts\ngot the alert.', 'Real-time delivery confirmation for every contact.'),
      'hi': ('जानें कि आपके संपर्कों को\nअलर्ट मिल गया।', 'हर संपर्क के लिए रीयल-टाइम डिलीवरी पुष्टि।'),
      'ta': ('உங்கள் தொடர்புகளுக்கு\nஎச்சரிக்கை கிடைத்ததை அறியுங்கள்.', 'ஒவ்வொரு தொடர்புக்கும் நிகழ்நேர டெலிவரி உறுதிப்படுத்தல்.'),
      'te': ('మీ పరిచయాలకు\nహెచ్చరిక అందిందని తెలుసుకోండి.', 'ప్రతి పరిచయానికి రియల్-టైమ్ డెలివరీ నిర్ధారణ.'),
    },
  ),
  _HeroScreen(
    number: 3,
    screenName: 'Evidence Vault (Day 82)',
    icon: Icons.lock_rounded,
    accentColor: Color(0xFFF59E0B),
    copy: {
      'en': ('Your evidence,\nsecure and sealed.', 'Audio, video, GPS and sensor data — court-ready.'),
      'hi': ('आपका सबूत,\nसुरक्षित और सीलबंद।', 'ऑडियो, वीडियो, GPS और सेंसर डेटा — अदालत के लिए तैयार।'),
      'ta': ('உங்கள் ஆதாரம்,\nபாதுகாப்பாகவும் முத்திரையிடப்பட்டும்.', 'ஆடியோ, வீடியோ, GPS மற்றும் சென்சார் தரவு — நீதிமன்றத்திற்கு தயார்.'),
      'te': ('మీ ఆధారాలు,\nసురక్షితంగా మరియు మూసివేయబడ్డాయి.', 'ఆడియో, వీడియో, GPS మరియు సెన్సార్ డేటా — కోర్టుకు సిద్ధం.'),
    },
  ),
  _HeroScreen(
    number: 4,
    screenName: 'Protection Score (Day 59)',
    icon: Icons.shield_rounded,
    accentColor: Color(0xFF3B82F6),
    copy: {
      'en': ('See your safety\nscore at a glance.', 'ZapSafe monitors 7 factors and gives you a live score.'),
      'hi': ('अपना सुरक्षा स्कोर\nएक नज़र में देखें।', 'ZapSafe 7 कारकों की निगरानी करता है और आपको लाइव स्कोर देता है।'),
      'ta': ('உங்கள் பாதுகாப்பு மதிப்பெண்ணை\nஒரே பார்வையில் காணுங்கள்.', 'ZapSafe 7 காரணிகளைக் கண்காணித்து உங்களுக்கு நேரடி மதிப்பெண் அளிக்கிறது.'),
      'te': ('మీ భద్రతా స్కోర్‌ను\nఒక్క చూపులో చూడండి.', 'ZapSafe 7 అంశాలను పర్యవేక్షించి మీకు లైవ్ స్కోర్ ఇస్తుంది.'),
    },
  ),
  _HeroScreen(
    number: 5,
    screenName: 'Check-in Timers (Day 65)',
    icon: Icons.timer_rounded,
    accentColor: Color(0xFF8B5CF6),
    copy: {
      'en': ("If you don't check in,\nwe check on you.", "Dead-man's switch — your contacts are notified automatically."),
      'hi': ('अगर आप चेक-इन नहीं करते,\nतो हम आप पर नज़र रखते हैं।', 'डेड-मैन स्विच — आपके संपर्कों को स्वचालित रूप से सूचित किया जाता है।'),
      'ta': ('நீங்கள் செக்-இன் செய்யவில்லை என்றால்,\nநாங்கள் உங்களை சரிபார்க்கிறோம்.', 'டெட்-மேன் ஸ்விட்ச் — உங்கள் தொடர்புகளுக்கு தானாகவே அறிவிக்கப்படும்.'),
      'te': ('మీరు చెక్-ఇన్ చేయకపోతే,\nమేము మిమ్మల్ని తనిఖీ చేస్తాము.', 'డెడ్-మ్యాన్ స్విచ్ — మీ పరిచయాలకు స్వయంచాలకంగా తెలియజేయబడుతుంది.'),
    },
  ),
  _HeroScreen(
    number: 6,
    screenName: 'Emergency Contacts (Day 83)',
    icon: Icons.people_rounded,
    accentColor: Color(0xFF10B981),
    copy: {
      'en': ('Build your\nsafety network.', 'Tier 1 → 2 → 3 escalation. Contacts you can count on.'),
      'hi': ('अपना\nसुरक्षा नेटवर्क बनाएं।', 'टियर 1 → 2 → 3 एस्केलेशन। संपर्क जिन पर आप भरोसा कर सकते हैं।'),
      'ta': ('உங்கள்\nபாதுகாப்பு நெட்வொர்க்கை உருவாக்குங்கள்.', 'நிலை 1 → 2 → 3 அதிகரிப்பு. நீங்கள் நம்பக்கூடிய தொடர்புகள்.'),
      'te': ('మీ\nభద్రతా నెట్‌వర్క్‌ను నిర్మించండి.', 'టైర్ 1 → 2 → 3 ఎస్కలేషన్. మీరు నమ్మగలిగే పరిచయాలు.'),
    },
  ),
];

const _kLanguages = [
  ('en', 'English'),
  ('hi', 'Hindi'),
  ('ta', 'Tamil'),
  ('te', 'Telugu'),
];

final _selectedScreenProvider = StateProvider<int>((ref) => 0);
final _selectedLangProvider = StateProvider<String>((ref) => 'en');

String _fileName(_HeroScreen s, String lang) =>
    'screenshot_${s.number}_${s.screenName.split(' ').first.toLowerCase()}_$lang.png';

String _buildManifest() {
  final buf = StringBuffer();
  buf.writeln('ZapSafe store screenshot asset manifest');
  buf.writeln('Play Store phone size: 1080 × 1920 px (portrait, PNG)');
  buf.writeln('Apple App Store: first 3 shown without scrolling');
  buf.writeln('${_kHeroScreens.length} screens × ${_kLanguages.length} languages = '
      '${_kHeroScreens.length * _kLanguages.length} files needed');
  buf.writeln('');
  for (final s in _kHeroScreens) {
    for (final (code, name) in _kLanguages) {
      final (headline, subline) = s.copy[code]!;
      buf.writeln(_fileName(s, code));
      buf.writeln('  screen: #${s.number} ${s.screenName}');
      buf.writeln('  language: $name ($code)');
      buf.writeln('  headline: ${headline.replaceAll('\n', ' / ')}');
      buf.writeln('  subline: $subline');
      buf.writeln('  status: NOT YET CAPTURED (needs real device/emulator)');
      buf.writeln('');
    }
  }
  return buf.toString();
}

class Day349StoreScreenshotsI18nScreen extends ConsumerWidget {
  const Day349StoreScreenshotsI18nScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenIdx = ref.watch(_selectedScreenProvider);
    final lang = ref.watch(_selectedLangProvider);
    final screen = _kHeroScreens[screenIdx];
    final (headline, subline) = screen.copy[lang]!;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: Text('day341_350.store_screenshots_title'.tr()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _kAccent.withOpacity(0.35)),
            ),
            child: const Text(
              '🟢 Section J Day 9/10 · 6 Day-191 hero screens × en/hi/ta/te',
              style: TextStyle(color: _kAccent, fontSize: 11),
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.warning.withOpacity(0.35)),
            ),
            child: const Text(
              'Honest limitation: no device/emulator in this environment, so '
              'no ACTUAL app screenshot can be captured. The frame below is a '
              'real, live-rendered layout MOCKUP — the real capture step '
              '(simulator/emulator → PNG) still needs a human on a real '
              'machine.',
              style: TextStyle(color: ZapColors.warning, fontSize: 11, height: 1.4),
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          const Text('Screen', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(height: ZapSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _kHeroScreens.map((s) {
              final selected = s.number - 1 == screenIdx;
              return ChoiceChip(
                label: Text('#${s.number}'),
                selected: selected,
                selectedColor: _kAccent.withOpacity(0.25),
                onSelected: (_) => ref.read(_selectedScreenProvider.notifier).state = s.number - 1,
              );
            }).toList(),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Text('Language', style: TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(height: ZapSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _kLanguages.map((l) {
              final selected = l.$1 == lang;
              return ChoiceChip(
                label: Text(l.$2),
                selected: selected,
                selectedColor: _kAccent.withOpacity(0.25),
                onSelected: (_) => ref.read(_selectedLangProvider.notifier).state = l.$1,
              );
            }).toList(),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Center(child: _FrameMockup(screen: screen, headline: headline, subline: subline, lang: lang)),
          const SizedBox(height: ZapSpacing.sm),
          Center(
            child: Text(
              _fileName(screen, lang),
              style: const TextStyle(color: ZapColors.textMuted, fontSize: 10, fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Asset manifest (${_kHeroScreens.length * _kLanguages.length} files)',
                style: const TextStyle(color: ZapColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 12),
              ),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _buildManifest()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Asset manifest copied to clipboard')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Export manifest', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZapColors.border),
            ),
            child: SelectableText(
              _buildManifest(),
              style: const TextStyle(
                  color: ZapColors.textSecondary, fontSize: 9, fontFamily: 'monospace', height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _FrameMockup extends StatelessWidget {
  const _FrameMockup({
    required this.screen,
    required this.headline,
    required this.subline,
    required this.lang,
  });

  final _HeroScreen screen;
  final String headline;
  final String subline;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 391, // 1080:1920 aspect ratio scaled down
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.grey.shade800, width: 4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [screen.accentColor.withOpacity(0.85), Colors.black],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
            // en/hi/ta/te are all LTR — this generator doesn't cover RTL
            // locales (ar/ur/fa store copy would need separate mirrored
            // mockups, out of scope for Day 349's en/hi/ta/te spec).
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subline,
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 10, height: 1.3),
                  ),
                  const Spacer(),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(screen.icon, color: Colors.white, size: 40),
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: Text(
                      'ZapSafe',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
