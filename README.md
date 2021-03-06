# Karmka Text Editor

Rich text editor for flutter based on this library: https://github.com/namhyun-gu/flutter_rich_text_editor.

Customized and extended for use in Karmka.

Most of this readme is taken from the source with added info where it's been extended.

## Requirements

Must be use flutter **v1.8.3** or later, Dart 2.2.2 or later

## Getting Started

* Add this lines to pubspec.yaml

```yaml
karmka_text_editor:
  git:
    url: https://github.com/tutosirisom/karmka_text_editor.git
```

## Using

* Import library 

```dart
import 'package:karmka_text_editor/rich_text_editor.dart';
```

* Initialize controller

> SpannableTextEditingController is extends TextEditingController. Therefore you can use TextEditingController interfaces.

```dart
SpannableTextEditingController controller = SpannableTextEditingController();

// Initialize with saved text (No style applied)
SpannableTextEditingController controller = SpannableTextEditingController(
  text: "Hello",
);

// Initialize with saved text and style
String savedStyleJson;

SpannableList styleList = SpannableList.fromJson(savedStyleJson); 
SpannableTextEditingController controller = SpannableTextEditingController(
  text: "Hello",
  styleList: styleList
);

// or

SpannableTextEditingController controller = SpannableTextEditingController.fromJson(
  text: "Hello",
  styleJson: savedStyleJson
);
```

* Add controller to TextField

```dart
TextField(
  controller: controller,
  keyboardType: TextInputType.multiline,
  maxLines: null,
  decoration: InputDecoration(
    border: InputBorder.none,
    focusedBorder: InputBorder.none,
    filled: false,
  ),
)
```

* Control selection style

```dart
// Set selection style
controller.setSelectionStyle((currentStyle) {
  var newStyle = currentStyle;
  // Set bold
  newStyle.setStyle(styleBold);
  return newStyle;
});

// Get selection style
SpannbleStyle style = controller.getSelectionStyle();
```

* Control composing style

```dart
var newStyle = controller.composingStyle;
// Set bold
newStyle.setStyle(styleBold);
controller.composingStyle = newStyle;
```

> Can use predefined StyleToolbar widget

```dart
StyleToolbar(
  controller: controller,
),
```

* Customize StyleToolbar widget

```dart
StyleToolbar(
  controller: controller,
  stayFocused: false,
  toolbarUndoRedoColor: Colors.white,
  toolbarActionColor: Colors.white.withOpacity(0.5),
  toolbarBackgroundColor: Colors.indigo,
  toolbarActionToggleColor: Colors.white,
),
```

* Undo & Redo operation

```dart
// Undo
controller.canUndo();
controller.undo();

// Redo
controller.canRedo();
controller.redo();
```

* Save style list

> Currently not support standard rich text format. can use json type list only.

```dart
controller.styleList.toJson();
```

* Use style list to RichText widget

```dart
String text;
SpannableList list;
TextStyle defaultStyle;

RichText(
  text: list.toTextSpan(text, defaultStyle: defaultStyle),
);
```

* Use SpannableStyle

```dart
// Font styles
var style = SpannableStyle();

style.setStyle(styleBold);
style.hasStyle(styleBold); // true
style.clearStyle(styleBold);
style.hasStyle(styleBold); // false

// Text foreground color
Color color = Colors.red;

style.setForegroundColor(color);
style.clearForegroundColor();
```
