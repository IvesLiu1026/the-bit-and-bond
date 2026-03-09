import 'dart:io';

final RegExp _dartStringLiteralPattern = RegExp(
  r'''("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')''',
);
final RegExp _cjkPattern = RegExp(r'[\u4E00-\u9FFF]');

const String _defaultBaselinePath = 'tool/hardcoded_strings_baseline.txt';
const List<String> _excludedPathFragments = <String>['/core/l10n/', '/l10n/'];
const List<String> _excludedFileSuffixes = <String>[
  '.g.dart',
  '.freezed.dart',
  '.mocks.dart',
  'firebase_options.dart',
];

void main(List<String> args) async {
  final writeBaseline = args.contains('--write-baseline');
  final checkOnly = args.isEmpty || args.contains('--check');
  final baselinePath = _resolveBaselinePath(args);
  final baselineFile = File(baselinePath);
  final repoRoot = Directory.current;
  final libRoot = Directory('${repoRoot.path}/lib');

  if (!await libRoot.exists()) {
    stderr.writeln('ERROR: lib/ directory not found under ${repoRoot.path}');
    exitCode = 2;
    return;
  }

  final findings = await _collectFindings(libRoot, repoRoot.path);
  final uniqueFindings = findings.toSet().toList()..sort();
  if (writeBaseline) {
    await baselineFile.parent.create(recursive: true);
    await baselineFile.writeAsString(
      uniqueFindings.join('\n') + (uniqueFindings.isEmpty ? '' : '\n'),
    );
    stdout.writeln(
      'Baseline updated: ${baselineFile.path} (${uniqueFindings.length} entries)',
    );
    return;
  }

  if (!checkOnly) {
    stderr.writeln(
      'Usage: dart run tool/check_hardcoded_strings.dart [--check | --write-baseline] [--baseline=path]',
    );
    exitCode = 2;
    return;
  }

  if (!await baselineFile.exists()) {
    stderr.writeln(
      'ERROR: baseline file missing at ${baselineFile.path}. Run with --write-baseline first.',
    );
    exitCode = 2;
    return;
  }

  final baseline = await baselineFile.readAsLines().then(
    (lines) => lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toSet(),
  );
  final current = uniqueFindings.toSet();
  final newEntries = current.difference(baseline).toList()..sort();

  if (newEntries.isNotEmpty) {
    stderr.writeln(
      'ERROR: Found ${newEntries.length} new hardcoded CJK string literal(s) outside l10n baseline.',
    );
    for (final entry in newEntries.take(80)) {
      stderr.writeln('  + $entry');
    }
    if (newEntries.length > 80) {
      stderr.writeln('  ... ${newEntries.length - 80} more');
    }
    stderr.writeln(
      'If intentional, migrate to l10n keys or update baseline with --write-baseline.',
    );
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'Hardcoded string check passed. Current entries: ${current.length}, baseline entries: ${baseline.length}.',
  );
}

Future<List<String>> _collectFindings(
  Directory libRoot,
  String rootPath,
) async {
  final findings = <String>[];
  await for (final entity in libRoot.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    if (_shouldSkip(entity.path)) {
      continue;
    }
    final relPath = _toPosixRelative(entity.path, rootPath);
    final lines = await entity.readAsLines();
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//')) {
        continue;
      }
      final matches = _dartStringLiteralPattern.allMatches(line);
      for (final match in matches) {
        final literal = match.group(0);
        if (literal == null || !_cjkPattern.hasMatch(literal)) {
          continue;
        }
        findings.add('$relPath:${_compactLine(line)}');
      }
    }
  }
  findings.sort();
  return findings;
}

String _resolveBaselinePath(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--baseline=')) {
      final value = arg.substring('--baseline='.length).trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
  }
  return _defaultBaselinePath;
}

bool _shouldSkip(String path) {
  final normalized = path.replaceAll('\\', '/');
  for (final fragment in _excludedPathFragments) {
    if (normalized.contains(fragment)) {
      return true;
    }
  }
  for (final suffix in _excludedFileSuffixes) {
    if (normalized.endsWith(suffix)) {
      return true;
    }
  }
  return false;
}

String _toPosixRelative(String absolutePath, String rootPath) {
  final absolute = absolutePath.replaceAll('\\', '/');
  final root = rootPath.replaceAll('\\', '/');
  if (absolute.startsWith('$root/')) {
    return absolute.substring(root.length + 1);
  }
  return absolute;
}

String _compactLine(String line) {
  final compact = line.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= 160) {
    return compact;
  }
  return '${compact.substring(0, 160)}...';
}
