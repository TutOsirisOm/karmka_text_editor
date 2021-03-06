/*
 * Karmka Text Editor
 * Copyright 2019 Adam Bahr.
 * https://github.com/TutOsirisOm/karmka_text_editor/
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * 
 * This project uses modified source code from https://github.com/namhyun-gu/flutter_rich_text_editor, copyright Namhyun Gu 2019, licensed under the Apache 2.0 license.
 */
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:karmka_text_editor/diff_patch_match/DiffMatchPatch.dart';

import 'spannable_list.dart';
import 'spannable_style.dart';

typedef SetStyleCallback = SpannableStyle Function(SpannableStyle style);

class SpannableTextEditingController extends TextEditingController {
  final int historyLength;

  SpannableList _currentStyleList;
  SpannableStyle _currentComposingStyle;

  Queue<ControllerHistory> _histories = Queue();
  Queue<ControllerHistory> _undoHistories = Queue();

  bool _updatedByHistory = false;

  /// These variables are needed for correctly handling auto-complete/case-correction on mobile devices
  bool _previouslyAutocorrected = false;
  bool _previouslyUpdatedCase = false;

  SpannableTextEditingController({
    String text = '',
    SpannableList styleList,
    SpannableStyle composingStyle,
    this.historyLength = 5,
  }) : super(text: text) {
    _currentStyleList = styleList ?? SpannableList.generate(text.length);
    _currentComposingStyle = composingStyle ?? SpannableStyle();
  }

  SpannableTextEditingController.fromJson({
    String text = '',
    String styleJson,
    SpannableStyle composingStyle,
    this.historyLength = 5,
  }) : super(text: text) {
    _currentStyleList = SpannableList.fromJson(styleJson) ??
        SpannableList.generate(text.length);
    _currentComposingStyle = composingStyle ?? SpannableStyle();
  }

  @override
  set value(TextEditingValue newValue) {
    if (value.text != newValue.text) {
      if (!_updatedByHistory) {
        _updateHistories(_histories);
        _undoHistories.clear();
        _updateList(value.text, newValue.text);
      }
      _updatedByHistory = false;
    }
    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({TextStyle style, bool withComposing}) {
    return _currentStyleList.toTextSpan(text, defaultStyle: style);
  }

  SpannableList get styleList => _currentStyleList.copy();

  SpannableStyle get composingStyle => _currentComposingStyle.copy();

  set composingStyle(SpannableStyle newComposingStyle) {
    _currentComposingStyle = newComposingStyle;
    notifyListeners();
  }

  void setSelectionStyle(SetStyleCallback callback) {
    if (selection.isValid && selection.isNormalized) {
      _updateHistories(_histories);
      for (var offset = selection.start; offset < selection.end; offset++) {
        _currentStyleList.modify(offset, callback);
      }
      notifyListeners();
    }
  }

  SpannableStyle getSelectionStyle() {
    if (selection.isValid && selection.isNormalized) {
      SpannableStyle style = SpannableStyle();

      var start = selection.start;
      var end = selection.end;
      var first = _currentStyleList.index(start);

      var foregroundColor =
          first.hasStyle(useForegroundColor) ? first.foregroundColor : null;
      var backgroundColor =
          first.hasStyle(useBackgroundColor) ? first.backgroundColor : null;

      for (var offset = start; offset < end; offset++) {
        final current = _currentStyleList.index(offset);
        style.setStyle(style.style | current.style);

        if (foregroundColor != null &&
            foregroundColor != current.foregroundColor) {
          foregroundColor = null;
        }
        if (backgroundColor != null &&
            backgroundColor != current.backgroundColor) {
          backgroundColor = null;
        }
      }
      if (foregroundColor != null) {
        style.setForegroundColor(getColorFromValue(foregroundColor));
      }
      if (backgroundColor != null) {
        style.setBackgroundColor(getColorFromValue(backgroundColor));
      }
      return style;
    }
    return null;
  }

  void clearComposingStyle() {
    _currentComposingStyle = SpannableStyle();
  }

  bool canUndo() => _histories.isNotEmpty;

  void undo() {
    assert(canUndo());
    _updateHistories(_undoHistories);
    _applyHistory(_histories.removeLast());
  }

  bool canRedo() => _undoHistories.isNotEmpty;

  void redo() {
    assert(canRedo());
    _updateHistories(_histories);
    _applyHistory(_undoHistories.removeLast());
  }

  void _applyHistory(ControllerHistory history) {
    _updatedByHistory = true;
    _currentStyleList = history.styleList;
    value = history.value;
  }

  void _updateHistories(Queue<ControllerHistory> histories) {
    if (histories.length == historyLength) {
      histories.removeFirst();
    }
    histories.add(ControllerHistory(
      value: value,
      styleList: _currentStyleList.copy(),
    ));
  }

  void _updateList(String oldText, String newText) {
    var textChange = _calculateTextChange(oldText, newText);
    var diffLength = (oldText.length - newText.length).abs();

    if (textChange != null && diffLength > 0) {
      var composedStyle = (composingStyle ?? SpannableStyle()).copy();
      if (diffLength > 0) {
        for (var index = 0; index < diffLength; index++) {
          if (textChange.operation == Operation.insert) {
            _currentStyleList.insert(textChange.offset + index, composedStyle);
          } else if (textChange.operation == Operation.delete) {
            _currentStyleList.delete(textChange.offset);
          }
        }
      }
    }
  }

  _TextChange _calculateTextChange(String oldText, String newText) {
    if (oldText == null) {
      return null;
    }

    var dmp = DiffMatchPatch();
    var diffList = dmp.diff_main(oldText, newText);
    var operation, length;
    var offset = 0;
    for (var index = 0; index < diffList.length; index++) {
      final diff = diffList[index];
      if (diff.operation == Operation.equal) {
        offset += diff.text.length;
      } else if (diff.operation == Operation.insert) {
        if (index + 1 < diffList.length) {
          final nextDiff = diffList[index + 1];
          if (nextDiff.operation == Operation.delete) {
            if (nextDiff.text.length == diff.text.length) {
              operation = Operation.delete;
              length = diff.text.length - nextDiff.text.length;
              break;
            }
            if (nextDiff.text.length < diff.text.length) {
              operation = Operation.delete;
              length = diff.text.length - nextDiff.text.length;
              break;
            }
          }
        }

        /// Resets the variables
        _previouslyUpdatedCase = false;
        _previouslyAutocorrected = false;
        operation = Operation.insert;
        length = diff.text.length;
        break;
      } else if (diff.operation == Operation.delete) {
        if (index + 1 < diffList.length) {
          final nextDiff = diffList[index + 1];
          if (nextDiff.operation == Operation.insert) {
            /// Runs when text is auto-corrected with a single case change (for example: lower-case to upper-case).
            if (nextDiff.text.length == diff.text.length) {
              /// Check to see if we previously updated case and if so block insertion and change operation to delete.
              /// This typically happens when back-spacing a previously case-corrected word.
              if (_previouslyUpdatedCase) {
                operation = Operation.delete;
                _previouslyUpdatedCase = true;
                _previouslyAutocorrected = false;
                length = diff.text.length;
                break;
              }

              /// Check to see if we previously auto-corrected a word and if so block insertion and change operation to delete.
              if (_previouslyAutocorrected) {
                operation = Operation.delete;
                _previouslyUpdatedCase = true;
                _previouslyAutocorrected = false;
                length = diff.text.length;
                break;
              }
              offset++;
              operation = Operation.insert;
              length = nextDiff.text.length + 1;
              _previouslyUpdatedCase = true;
              _previouslyAutocorrected = false;
              break;
            }

            /// Runs when text is auto-corrected or auto-completed
            if (nextDiff.text.length > diff.text.length) {
              offset++;
              operation = Operation.insert;
              length = nextDiff.text.length - diff.text.length;
              _previouslyAutocorrected = true;
              _previouslyUpdatedCase = false;
              break;
            }
          }
        }
        operation = Operation.delete;
        _previouslyUpdatedCase = false;
        _previouslyAutocorrected = false;
        length = diff.text.length;
        break;
      }
    }

    if (operation != null) {
      return _TextChange(operation, offset, length);
    } else {
      return null;
    }
  }
}

@immutable
class ControllerHistory {
  final TextEditingValue value;
  final SpannableList styleList;

  ControllerHistory({
    this.value,
    this.styleList,
  });

  @override
  String toString() {
    return '_ControllerHistory(text: ${value.text}, styleList: $styleList)';
  }
}

@immutable
class _TextChange {
  final Operation operation;
  final int offset;
  final int length;

  _TextChange(this.operation, this.offset, this.length);

  @override
  String toString() {
    return '$runtimeType(operation: $operation, offset: $offset, length: $length)';
  }
}
