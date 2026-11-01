#!/usr/bin/env python3
"""Fail closed on failed/cancelled/missing mandatory jobs or invalid selection."""
import json
import os


def errors(needs):
    problems = []
    for name in ('changes', 'docs'):
        if needs.get(name, {}).get('result') != 'success':
            problems.append(name + ': mandatory job did not succeed')
    plan = needs.get('changes', {}).get('outputs', {})
    for name in ('runtime', 'web', 'package'):
        selected = plan.get(name)
        result = needs.get(name, {}).get('result')
        if selected not in ('true', 'false'):
            problems.append(name + ': missing/invalid selection')
        elif selected == 'true' and result != 'success':
            problems.append(name + ': selected job did not succeed')
        elif selected == 'false' and result not in ('skipped', 'success'):
            problems.append(name + ': unselected job failed, cancelled or missing')
    return problems


if __name__ == '__main__':
    problems = errors(json.loads(os.environ['CI_NEEDS']))
    if problems:
        raise SystemExit('\n'.join(problems))
    print('[ci-gate] all required jobs succeeded; only unselected jobs may be skipped')
