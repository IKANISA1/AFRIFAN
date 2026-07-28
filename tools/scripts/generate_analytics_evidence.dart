import 'dart:convert';
import 'dart:io';

import 'package:core_network/src/privacy_safe_analytics.dart';

void main() {
  final root = _workspaceRoot();
  final output = File(
    '$root/output/implementation_goal_20260724/analytics-reviewed-output.json',
  );
  final policyFile = File(
    '$root/packages/core/core_network/lib/src/privacy_safe_analytics.dart',
  );

  final samples = <String, Map<String, Object>>{
    'home_action_selected': <String, Object>{
      'action': 'tickets',
      'layer': 'primary',
    },
    'search_success': <String, Object>{
      'category': 'commerce',
      'result_count_bucket': 'two_to_five',
    },
    'ticket_completion': <String, Object>{
      'ticket_type': 'matchday',
      'payment_channel': 'momo',
    },
    'contribution_completion': <String, Object>{
      'payment_channel': 'momo',
      'value_bucket': '1000_9999',
    },
    'fanzone_engagement': <String, Object>{
      'surface': 'supporters',
      'action': 'open',
    },
    'support_access': <String, Object>{'channel': 'whatsapp'},
    'error_recovery': <String, Object>{
      'surface': 'settings',
      'outcome': 'retry_success',
    },
    'task_abandonment': <String, Object>{
      'task': 'ticket_checkout',
      'stage': 'payment_handoff',
    },
  };

  final accepted = samples.entries
      .map((entry) {
        final event = PrivacySafeAnalyticsPolicy.prepare(
          entry.key,
          parameters: entry.value,
        );
        if (event == null) {
          stderr.writeln('Declared sample was rejected: ${entry.key}');
          exitCode = 1;
          return <String, Object>{};
        }
        return event.toJson();
      })
      .toList(growable: false);
  if (exitCode != 0) return;

  final rejectedChecks = <Map<String, Object>>[
    <String, Object>{
      'case': 'unknown_event',
      'rejected':
          PrivacySafeAnalyticsPolicy.prepare('outside_contract') == null,
    },
    <String, Object>{
      'case': 'unknown_parameter',
      'rejected':
          PrivacySafeAnalyticsPolicy.prepare(
            'support_access',
            parameters: const <String, Object>{
              'channel': 'whatsapp',
              'account_identifier': 'synthetic',
            },
          ) ==
          null,
    },
    <String, Object>{
      'case': 'free_text_value',
      'rejected':
          PrivacySafeAnalyticsPolicy.prepare(
            'support_access',
            parameters: const <String, Object>{'channel': 'not a coded value'},
          ) ==
          null,
    },
    <String, Object>{
      'case': 'precise_numeric_value',
      'rejected':
          PrivacySafeAnalyticsPolicy.prepare(
            'contribution_completion',
            parameters: const <String, Object>{
              'payment_channel': 'momo',
              'value_bucket': 5000,
            },
          ) ==
          null,
    },
  ];
  if (rejectedChecks.any((check) => check['rejected'] != true)) {
    stderr.writeln('A negative analytics policy check was not rejected.');
    exitCode = 1;
    return;
  }

  final gitSha = _run(root, 'git', <String>['rev-parse', 'HEAD']);
  final dirty = _run(root, 'git', <String>['status', '--porcelain']).isNotEmpty;
  final policySha = _run(root, 'shasum', <String>[
    '-a',
    '256',
    policyFile.path,
  ]).split(RegExp(r'\s+')).first;

  final report = <String, Object>{
    'schema_version': '1.0',
    'generated_at': DateTime.now().toUtc().toIso8601String(),
    'status': 'pass',
    'provenance': <String, Object>{
      'commit_sha': gitSha,
      'dirty': dirty,
      'policy_path': policyFile.path,
      'policy_sha256': policySha,
      'data_source': 'synthetic_non_production',
    },
    'consent_contract': <String, Object>{
      'default': 'disabled',
      'basis': 'explicit_opt_in',
      'compile_time_release_gate': 'ENABLE_FIREBASE_OBSERVABILITY',
      'identifiers_permitted': false,
      'free_text_permitted': false,
      'precise_transaction_values_permitted': false,
    },
    'accepted_required_event_samples': accepted,
    'rejected_policy_checks': rejectedChecks,
    'dashboard_contract': <String, Object>{
      'dimensions': <String>[
        'event_name',
        'coded_surface_or_category',
        'coarse_value_or_count_bucket',
      ],
      'measures': <String>[
        'consented_event_count',
        'task_completion_count',
        'recovery_success_count',
        'abandonment_count',
      ],
      'minimum_reporting_threshold': 20,
      'small_cohort_suppression_required': true,
    },
    'review': <String, Object>{
      'automated_policy_review': 'pass',
      'accountable_human_review': 'pending',
      'production_dashboard_connected': false,
    },
    'completion_claim': false,
  };

  output.parent.createSync(recursive: true);
  final encodedReport = const JsonEncoder.withIndent('  ').convert(report);
  output.writeAsStringSync('$encodedReport\n');
  stdout.writeln('Analytics evidence generated: ${output.path}');
}

String _workspaceRoot() {
  final script = File(Platform.script.toFilePath()).absolute;
  return script.parent.parent.parent.path;
}

String _run(String root, String executable, List<String> arguments) {
  final result = Process.runSync(executable, arguments, workingDirectory: root);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    exit(result.exitCode);
  }
  return result.stdout.toString().trim();
}
