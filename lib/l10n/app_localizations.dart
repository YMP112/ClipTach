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
      'autoAssist': 'Auto Assist',
      'autoAssistMultiObject': 'Multi Object',
      'maskTool': 'Mask Tool',
      'brushTool': 'Brush',
      'polygonKeepTool': 'Polygon Keep',
      'applyPolygon': 'Apply Polygon',
      'clearPolygon': 'Clear Polygon',
      'polygonMultiHint': 'You can apply multiple polygons one after another.',
      'deletePoint': 'Delete Point',
      'editObject': 'Edit Object',
      'editMask': 'Edit Mask',
      'scale': 'Scale',
      'rotate': 'Rotate',
      'skew': 'Skew',
      'hintNoImage': 'Open an image to start.',
      'language': 'Language',
      'homeIntro':
          'Open an image, mark what to keep, and export a transparent PNG.',
      'recentProjects': 'Recent Projects',
      'noRecentProjects': 'No recent projects yet.',
      'handMode': 'Hand Mode',
      'widthPx': 'Width (px)',
      'heightPx': 'Height (px)',
      'original': 'Original',
      'fileName': 'File name',
      'exportDialogTitle': 'Export PNG',
      'exportLocation': 'Export Folder',
      'exportNoFolder': 'No folder selected',
      'choose': 'Choose...',
      'exportMode': 'Export Mode',
      'withMargins': 'With Margins',
      'objectOnly': 'Object Only',
      'objectOnlyHint': 'Object only (tight rectangle)',
      'marginsPx': 'Margins (px):',
      'cancel': 'Cancel',
      'choosePathError': 'Choose an export folder.',
      'marginError': 'Margin must be a non-negative integer.',
      'exportSuccess': 'Exported successfully:',
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
      'autoAssist': 'סיוע אוטומטי',
      'autoAssistMultiObject': 'בחירה מרובה',
      'maskTool': 'כלי סימון',
      'brushTool': 'מברשת',
      'polygonKeepTool': 'פוליגון שמירה',
      'applyPolygon': 'החל פוליגון',
      'clearPolygon': 'נקה פוליגון',
      'polygonMultiHint': 'אפשר להחיל כמה פוליגונים ברצף.',
      'deletePoint': 'מחק נקודה',
      'editObject': 'ערוך אובייקט',
      'editMask': 'ערוך מסכה',
      'scale': 'קנה מידה',
      'rotate': 'סיבוב',
      'skew': 'הטיה',
      'hintNoImage': 'פתח תמונה כדי להתחיל.',
      'language': 'שפה',
      'homeIntro': 'פתח תמונה, סמן מה לשמור, וייצא PNG שקוף במהירות.',
      'recentProjects': 'פרויקטים אחרונים',
      'noRecentProjects': 'אין פרויקטים אחרונים עדיין.',
      'handMode': 'מצב יד',
      'widthPx': 'רוחב (פיקסלים)',
      'heightPx': 'גובה (פיקסלים)',
      'original': 'מקורי',
      'fileName': 'שם קובץ',
      'exportDialogTitle': 'ייצוא PNG',
      'exportLocation': 'תיקיית ייצוא',
      'exportNoFolder': 'לא נבחרה תיקייה',
      'choose': 'בחר...',
      'exportMode': 'מצב ייצוא',
      'withMargins': 'עם שוליים',
      'objectOnly': 'אובייקט בלבד',
      'objectOnlyHint': 'אובייקט בלבד (מלבן צמוד)',
      'marginsPx': 'שוליים (פיקסלים):',
      'cancel': 'ביטול',
      'choosePathError': 'בחר תיקיית ייצוא.',
      'marginError': 'ערך השוליים חייב להיות מספר שלם לא שלילי.',
      'exportSuccess': 'יוצא בהצלחה:',
    },
  };

  String t(String key) {
    final lang = _values[locale.languageCode] ?? _values['en']!;
    return lang[key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
        (supported) => supported.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
