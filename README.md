# ClipTach

ClipTach היא אפליקציה ממוקדת לחילוץ אובייקט מתוך תמונה בעזרת סימון מונחה־משתמש, מחיקת הרקע, וייצוא התוצאה כ־PNG שקוף.

## מטרת המוצר

- לא עורך תמונות כללי
- לא פילטרים / שכבות מורכבות
- כן זרימה מהירה וברורה: `Open -> Mark Keep/Erase -> Extract -> Transform -> Export`

## MVP נוכחי

- פתיחת תמונה
- סימון מסכה ידני (`Keep` / `Erase`)
- בניית Alpha Mask
- Auto Assist ראשוני (הצעת סימון התחלתית לשיפור מהירות עבודה)
- תצוגת אובייקט מחולץ על רקע שקוף
- טרנספורמציות בסיסיות: `Move`, `Scale`, `Rotate`, `Skew`
- ייצוא PNG שקוף
- שמירת/טעינת פרויקט בפורמט ייעודי `*.cliptach` (ZIP ארוז עם `project.json` ונתוני מקור)
- ממשק דו־לשוני עברית/אנגלית

## ארכיטקטורה (בקצרה)

- `lib/features/editor/presentation` - UI וקנבס
- `lib/features/editor/application` - בקר לוגיקה ו־state transitions
- `lib/features/editor/domain` - מודלי מצב ועריכה
- `lib/features/editor/infrastructure` - IO ועיבוד תמונה
- `lib/core/services` - אריזה/פריקה של פורמט הפרויקט
- `lib/l10n` - לוקליזציה

## טכנולוגיות

- Flutter + Dart
- Riverpod (state management)
- file_picker (open/save)
- archive (פורמט `*.cliptach`)

## הרצה מקומית

1. התקן Flutter SDK.
2. הרץ:

```bash
flutter pub get
flutter run
```

## בדיקות וסטטיות

```bash
flutter format .
flutter analyze
flutter test
```

## שלב הבא (Post-MVP)

- contour assist / edge snapping
- הצעת מסכה התחלתית אוטומטית
- שיפור חכם של קווי מתאר
