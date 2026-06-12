// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:dart_style/src/testing/benchmark.dart';
import 'package:path/path.dart' as p;

void main() {
    var casesDir = Directory('benchmark/case');
    for (var entry in casesDir.listSync()) {
        var ext = p.extension(entry.path);
        if (ext != '.unit' && ext != '.stmt') continue;

        var lines = File(entry.path).readAsLinesSync();
        var pageWidth = 80;
        if (lines[0].endsWith('|')) {
            pageWidth = lines[0].indexOf('|');
            lines.removeAt(0);
        }
        var input = lines.join('\n');
        var isUnit = ext == '.unit';

        for (var tall in [true, false]) {
            var formatter = DartFormatter(
                languageVersion: tall
                    ? DartFormatter.latestLanguageVersion
                    : DartFormatter.latestShortStyleLanguageVersion,
                pageWidth: pageWidth,
            );
            var result = formatter.formatSource(SourceCode(input, isCompilationUnit: isUnit));
            var text = result.text;
            if (!isUnit) text += '\n';

            var outPath = p.setExtension(entry.path, tall ? '.expect' : '.expect_short');
            File(outPath).writeAsStringSync(text);
            print('Updated ${p.basename(outPath)}');
        }
    }
}
