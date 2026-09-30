# Task dependency and closure planner

`task_execution_plan.py` reads the existing register without changing task IDs, priorities,
owner roles, dependency wording, status or acceptance requirements. It does not execute
commands from task text, assign people, infer approvals or close tasks.

```sh
python3 tools/scripts/task_execution_plan.py --register /path/TASK_REGISTER.json \
  --output /path/new-execution-plan.json
```

The output uses exclusive creation and binds the input to a SHA-256. It produces
priority-ordered topological layers, missing dependency/cycle diagnostics, unresolved
closure prerequisites and missing named-owner counts. Dependencies are **closure**
prerequisites: independent source implementation can proceed in parallel.

A Closed/accepted declaration without a named owner and closure reference is an issue,
as is accepting a task while its prerequisite is unaccepted. Even structurally complete
declarations are not independently verified. Use the existing `release_evidence.py` and
migration release verifier for their narrower candidate-bound evidence checks and obtain
authentic accountable sign-off. `releaseAuthorized` is always false in this planner.

All 130 baseline tasks form an acyclic graph with 19 prerequisite layers. This observation
is tied to Implementation 03's register, not a perpetual statement about later versions.
Every one of those baseline tasks lacks an assigned named owner. The generated updated
plan keeps source work separate from external approvals and runtime acceptance.
