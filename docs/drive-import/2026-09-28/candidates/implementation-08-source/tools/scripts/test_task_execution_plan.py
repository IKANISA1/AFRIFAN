import copy
import json
import pathlib
import tempfile
import unittest
from task_execution_plan import plan, InvalidRegister


def task(key, deps='', priority='P1'):
    return {'id': key, 'task': 'Synthetic source work', 'workstream': 'test', 'owner_role': 'Developer',
            'priority': priority, 'status': 'Open', 'dependencies': deps, 'release_accepted': False,
            'acceptance_evidence': 'Actual named acceptance required.', 'assigned_owner': '', 'closure_link': ''}

class TaskPlanTests(unittest.TestCase):
    def test_layers_preserve_dependencies(self):
        p = plan({'tasks': [task('REP-01'), task('QAT-01', 'REP-01'), task('REL-01', 'QAT-01')]})
        self.assertEqual(p['dependencyLayers'], [['REP-01'], ['QAT-01'], ['REL-01']])
    def test_priority_does_not_jump_prerequisite(self):
        p = plan({'tasks': [task('REP-01', priority='P2'), task('QAT-01', 'REP-01', 'P0')]})
        self.assertEqual(p['dependencyLayers'][0], ['REP-01'])
    def test_parallel_roots_sorted_by_priority(self):
        p = plan({'tasks': [task('REP-01'), task('SEC-01', priority='P0')]})
        self.assertEqual(p['dependencyLayers'], [['SEC-01', 'REP-01']])
    def test_missing_dependency_has_no_implicit_acceptance(self):
        p = plan({'tasks': [task('QAT-01', 'REP-01')]})
        self.assertEqual(p['issues'][0]['code'], 'missing_dependency'); self.assertEqual(p['unscheduledTaskIds'], ['QAT-01'])
    def test_cycle_separate_from_downstream_blockage(self):
        p = plan({'tasks': [task('REP-01', 'REP-02'), task('REP-02', 'REP-01'), task('QAT-01', 'REP-01')]})
        self.assertEqual(p['cyclicTaskIds'], ['REP-01', 'REP-02']); self.assertEqual(len(p['unscheduledTaskIds']), 3)
    def test_self_cycle(self):
        p = plan({'tasks': [task('REP-01', 'REP-01')]}); self.assertEqual(p['cyclicTaskIds'], ['REP-01'])
    def test_duplicate_ids_rejected(self):
        with self.assertRaises(InvalidRegister): plan({'tasks': [task('REP-01'), task('REP-01')]})
    def test_empty_register_rejected(self):
        with self.assertRaises(InvalidRegister): plan({'tasks': []})
    def test_bad_dependency_separator_rejected(self):
        with self.assertRaises(InvalidRegister): plan({'tasks': [task('REP-01', 'SEC-01, SEC-02')]})
    def test_duplicate_dependency_rejected(self):
        with self.assertRaises(InvalidRegister): plan({'tasks': [task('REP-01', 'SEC-01; SEC-01')]})
    def test_nonboolean_approval_rejected(self):
        t = task('REP-01'); t['release_accepted'] = 'false'
        with self.assertRaises(InvalidRegister): plan({'tasks': [t]})
    def test_unknown_status_rejected(self):
        t = task('REP-01'); t['status'] = 'probably done'
        with self.assertRaises(InvalidRegister): plan({'tasks': [t]})
    def test_closed_without_approval_is_issue(self):
        t = task('REP-01'); t['status'] = 'Closed'
        self.assertEqual(plan({'tasks': [t]})['issues'][0]['code'], 'unsubstantiated_closure_declaration')
    def test_approved_without_owner_is_issue(self):
        t = task('REP-01'); t.update(status='Closed', release_accepted=True, closure_link='review.txt')
        self.assertTrue(plan({'tasks': [t]})['issues'])
    def test_approval_does_not_verify_or_authorize(self):
        t = task('REP-01'); t.update(status='Closed', release_accepted=True, assigned_owner='Reviewer', closure_link='review.txt')
        p = plan({'tasks': [t]}); self.assertFalse(p['approvalEvidenceVerified']); self.assertFalse(p['releaseAuthorized'])
    def test_unaccepted_dependency_invalidates_closure(self):
        t = task('QAT-01', 'REP-01'); t.update(status='Closed', release_accepted=True, assigned_owner='Reviewer', closure_link='review.txt')
        self.assertEqual(plan({'tasks': [task('REP-01'), t]})['issues'][0]['code'], 'accepted_with_unaccepted_dependencies')
    def test_no_mutation_of_source_register(self):
        r = {'tasks': [task('REP-01'), task('QAT-01', 'REP-01')]}; before = copy.deepcopy(r); plan(r); self.assertEqual(r, before)
    def test_original_acceptance_and_dependencies_preserved(self):
        t = task('REP-01', 'SEC-01'); p = plan({'tasks': [t, task('SEC-01')]})
        row = next(x for x in p['tasks'] if x['id'] == 'REP-01'); self.assertEqual(row['closureEvidenceRequired'], t['acceptance_evidence']); self.assertEqual(row['unacceptedDependencies'], ['SEC-01'])
    def test_shell_text_not_executed(self):
        with tempfile.TemporaryDirectory() as d:
            target = pathlib.Path(d)/'unexpected'; t = task('REP-01'); t['task'] = f'touch {target}'
            p = plan({'tasks': [t]}); self.assertFalse(target.exists()); self.assertEqual(p['tasks'][0]['task'], t['task'])
    def test_stable_output_and_source_digest(self):
        r = {'tasks': [task('REP-01')]}; self.assertEqual(plan(r), plan(r)); self.assertEqual(len(plan(r)['sourceRegisterSha256']), 64)

if __name__ == '__main__': unittest.main()
