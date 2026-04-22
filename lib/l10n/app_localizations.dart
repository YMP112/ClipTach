import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('he'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final AppLocalizations? localization =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(localization != null, 'AppLocalizations not found in context');
    return localization!;
  }

  static const Map<String, Map<String, String>> _values = {
    'en': {
      'appTitle': 'ClipTach',
      'openImage': 'Open Image',
      'saveProject': 'Save Project',
      'loadProject': 'Load Project',
      'exportPng': 'Export PNG',
      'undo': 'Undo',
      'redo': 'Redo',
      'reset': 'Reset',
      'keep': 'Keep',
      'erase': 'Erase',
      'showMask': 'Show Mask',
      'brushSize': 'Brush Size',
      'extractObject': 'Extract Object',
      'editObject': 'Edit Object',
      'editMask': 'Edit Mask',
      'scale': 'Scale',
      'rotate': 'Rotate',
      'skew': 'Skew',
      'hintNoImage': 'Open an image to start.',
      'language': 'Language',
    },
    'he': {
      'appTitle': 'ClipTach',
      'openImage': 'פתח תמונה',
      'saveProject': 'שמור פרויקט',
      'loadProject': 'טען פרויקט',
      'exportPng': 'ייצא PNG',
      'undo': 'בטל',
      'redo': 'בצע שוב',
      'reset': 'אפס',
      'keep': 'שמור',
      'erase': 'מחק',
      'showMask': 'הצג מסכה',
      'brushSize': 'גודל מברשת',
      'extractObject': 'חלץ אובייקט',
      'editObject': 'ערוך אובייקט',
      'editMask': 'ערוך מסכה',
      'scale': 'קנה מידה',
      'rotate': 'סיבוב',
      'skew': 'הטיה',
      'hintNoImage': 'פתח תמונה כדי להתחיל.',
      'language': 'שפה',
    },
  };

  String t(String key) {
    final lang = _values[locale.languageCode] ?? _values['en']!;
    return lang[key] ?? key;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any(
        (supported) => supported.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
