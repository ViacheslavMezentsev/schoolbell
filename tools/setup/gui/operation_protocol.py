"""Local control channel, separate from untrusted human/SSH output."""
import json
import os
from pathlib import Path
import re
import subprocess

RESULTS = {
    'inspect-zip': {'idle'}, 'prepare': {'ready', 'current'},
    'install': {'done'}, 'verify': {'done', 'not-applied'},
    'backup': {'backedup'}, 'new-session': {'idle'},
}
class Cancelled(Exception):
    pass

class Operation:
    def __init__(self, args):
        if not re.fullmatch(r'[a-f0-9]{32}', args.operation_id):
            raise ValueError('Invalid operation ID')
        if not re.fullmatch(r'[a-f0-9]{64}', args.session_id):
            raise ValueError('Invalid session ID')
        self.action=args.action
        self.operation=args.operation_id
        self.session=args.session_id
        self.path=Path(args.session).parent/'operations'/(self.operation+'.json')
        self.path.parent.mkdir(exist_ok=True)
        self.cancel_path=self.path.with_suffix('.cancel')
        self.sequence=0
        if self.path.exists():
            raise ValueError('Operation ID already used')

    def event(self, kind, value):
        self.sequence+=1
        row=dict(protocol=1, operation=self.operation, session=self.session,
                 action=self.action, sequence=self.sequence, kind=kind, value=value)
        temporary=self.path.with_suffix('.tmp')
        with temporary.open('w',encoding='utf8') as f:
            json.dump(row,f);f.flush();os.fsync(f.fileno())
        os.replace(temporary,self.path)

    def checkpoint(self):
        if self.action not in ('install','new-session') and self.cancel_path.exists():
            raise Cancelled('Операция отменена. Сохранённые материалы остаются на ПК.')

    def execute(self, args, dispatch):
        self.event('phase','starting')
        args.check_cancel=self.checkpoint
        args.phase=lambda value:self.event('phase',value)
        try:
            self.checkpoint()
            result=dispatch(args)
            if result not in RESULTS[self.action]:
                raise ValueError('Worker returned no valid operation result')
            self.event('completed',result)
            return result
        except Cancelled:
            self.event('cancelled','cancelled')
            raise
        except Exception as error:
            code='timeout' if isinstance(error,subprocess.TimeoutExpired) else 'transport-failed' if isinstance(error,subprocess.CalledProcessError) else 'validation-failed' if isinstance(error,ValueError) else 'operation-failed'
            self.event('failed',code)
            raise


def checkpoint(args):
    getattr(args,'check_cancel',lambda:None)()


def phase(args,value):
    getattr(args,'phase',lambda value:None)(value)
