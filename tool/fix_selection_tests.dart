// Updates selection test files: replaces 2-space indentation with 4-space
// in expected output sections (<<< blocks), without touching input sections.
import 'dart:io';
import 'dart:math';

void main() {
    var files = [
        'test/tall/other/format_off_selection.unit',
        'test/tall/other/selection.stmt',
        'test/tall/other/selection.unit',
        'test/tall/other/selection_comma.stmt',
        'test/tall/other/selection_comment.stmt',
    ];

    for (var path in files) {
        _fixFile(path);
    }
}

/// Rewrites [path] so that lines in <<< output sections have their leading
/// indentation doubled (2→4, 4→8, etc.).
void _fixFile(String path) {
    var lines = File(path).readAsLinesSync();
    var result = <String>[];
    var inOutput = false;

    for (var line in lines) {
        if (line.startsWith('>>>')) {
            inOutput = false;
            result.add(line);
        } else if (line.startsWith('<<<')) {
            inOutput = true;
            result.add(line);
        } else if (inOutput) {
            result.add(_reindent(line));
        } else {
            result.add(line);
        }
    }

    File(path).writeAsStringSync('${result.join('\n')}\n');
    print('Fixed $path');
}

/// Doubles the leading spaces on [line].
///
/// Only expands runs of spaces at the start of the line, turning each
/// group of 2 spaces into 4.  Lines with no leading spaces are unchanged.
String _reindent(String line) {
    var leadingSpaces = 0;
    while (leadingSpaces < line.length && line[leadingSpaces] == ' ') {
        leadingSpaces++;
    }
    if (leadingSpaces == 0) return line;

    // Round up to nearest multiple of 2, then double.
    var newIndent = leadingSpaces * 2;
    return ' ' * newIndent + line.substring(leadingSpaces);
}
