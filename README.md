# My Todos

A simple Flutter todo app for Android.

## Features

- Add, edit, and delete tasks
- Mark tasks complete / incomplete
- Optional notes per task
- **Task priorities** — Low / Medium / High with color-coded badges
- Tasks are auto-sorted: incomplete first, then by priority, then by recency
- Filter: All, Active, Done
- Clear completed tasks (with undo)
- Swipe to delete with undo
- Local persistence (survives app restarts)
- Light & dark themes

## Develop

```bash
flutter pub get
flutter run
```

## Build a debug APK

```bash
flutter build apk --debug
```

## Test

```bash
flutter test
```

## Download

After a successful GitHub Actions build, grab the APK from the **Artifacts** section of the latest workflow run:
https://github.com/chalaha728-lab/todo/actions
