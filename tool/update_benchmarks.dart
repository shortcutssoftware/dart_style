// Regenerates benchmark .expect files based on current formatter output.
import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:dart_style/src/dart_version_history.dart';
import 'package:dart_style/src/testing/benchmark.dart';
import 'package:dart_style/src/testing/test_file.dart';
import 'package:path/path.dart' as p;

void main() async {
    var packageDir = await findPackageDirectory();
    var casesDir = p.join(packageDir, 'benchmark/case');

    for (var benchmark in Benchmark.findAll(packageDir)) {
        var formatter = DartFormatter(
            languageVersion: DartFormatter.latestLanguageVersion,
            pageWidth: benchmark.pageWidth,
        );
        var output = formatter.format(benchmark.input);

        var ext = benchmark.isCompilationUnit ? '.unit' : '.stmt';
        var inputPath = p.join(casesDir, '${benchmark.name}$ext');
        var expectPath = p.setExtension(inputPath, '.expect');
        File(expectPath).writeAsStringSync(output);
        print('Updated ${benchmark.name}.expect');
    }
}
