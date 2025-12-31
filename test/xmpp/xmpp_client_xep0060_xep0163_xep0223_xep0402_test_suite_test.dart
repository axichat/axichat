import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _planPath =
    'docs/xmpp_client_xep0060_xep0163_xep0223_xep0402_test_plan.md';
const String _skipReason =
    'Not implemented yet; requires pubsub and PEP protocol harness coverage.';
const String _missingPlanMessage = 'Missing test plan at $_planPath.';
const String _emptyString = '';
const String _labelSeparator = ' ';
const String _titleSeparator = ': ';
const String _planCasePatternSource =
    r'^\s*-\s+\*\*([A-Z0-9][A-Z0-9.\-]+(?:\s+\[[^\]]+\])+)\*\*\s+(.*)$';
const String _planCoverageGroupName =
    'XMPP client XEP-0060/0163/0223/0402 plan coverage';
const String _planExistsTestName = 'Loads test plan cases from markdown';
const String _planCoverageTestName = 'Implemented IDs are present in the plan';
const String _planUniqueIdsTestName = 'Plan IDs are unique';
const String _testSuiteGroupName =
    'XMPP client XEP-0060/0163/0223/0402 test suite';

final RegExp _planCasePattern = RegExp(_planCasePatternSource);

typedef _PlanTest = FutureOr<void> Function();

class _PlanCase {
  const _PlanCase({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;
}

final Map<String, _PlanTest> _implementedCases = <String, _PlanTest>{};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<_PlanCase> planCases = _loadPlanCases();

  group(_planCoverageGroupName, () {
    test(_planExistsTestName, () {
      expect(planCases, isNotEmpty);
    });

    test(_planUniqueIdsTestName, () {
      final Set<String> planIds =
          planCases.map((planCase) => planCase.id).toSet();
      expect(planIds.length, equals(planCases.length));
    });

    test(_planCoverageTestName, () {
      final Set<String> planIds =
          planCases.map((planCase) => planCase.id).toSet();
      expect(_implementedCases.keys, everyElement(isIn(planIds)));
    });
  });

  group(_testSuiteGroupName, () {
    for (final _PlanCase planCase in planCases) {
      final _PlanTest? implementation = _implementedCases[planCase.id];
      final Object? skipValue = implementation == null ? _skipReason : null;
      test(
        _planCaseTitle(planCase),
        implementation ?? _unimplementedPlanTest,
        skip: skipValue,
      );
    }
  });
}

List<_PlanCase> _loadPlanCases() {
  final File planFile = File(_planPath);
  if (!planFile.existsSync()) {
    throw StateError(_missingPlanMessage);
  }

  final List<String> lines = planFile.readAsLinesSync();
  final List<_PlanCase> cases = <_PlanCase>[];
  for (final String line in lines) {
    final RegExpMatch? match = _planCasePattern.firstMatch(line);
    if (match == null) {
      continue;
    }
    final String label = match.group(1)!.trim();
    final String description = match.group(2)!.trim();
    final String id = label.split(_labelSeparator).first;
    if (id == _emptyString || description == _emptyString) {
      continue;
    }
    cases.add(
      _PlanCase(
        id: id,
        label: label,
        description: description,
      ),
    );
  }
  return cases;
}

String _planCaseTitle(_PlanCase planCase) =>
    '${planCase.label}$_titleSeparator${planCase.description}';

void _unimplementedPlanTest() {}
