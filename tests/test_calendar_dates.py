#!/usr/bin/env python3
"""Independent Python datetime oracle: month boundaries across a 400-year cycle."""
import calendar
import datetime as dt
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
epoch = dt.date(1970, 1, 1)
dates = set()
for year in range(2000, 2400):
    for month in range(1, 13):
        last = calendar.monthrange(year, month)[1]
        for day in (1, last-1, last):
            dates.add(dt.date(year, month, day))
for date in (dt.date(1,1,2), dt.date(9999,12,30), dt.date(1900,2,28), dt.date(1970,1,1)):
    dates.add(date)
with tempfile.TemporaryDirectory(prefix='schoolbell-calendar-') as directory:
    oracle = Path(directory)/'dates.tsv'
    with oracle.open('w') as output:
        for date in sorted(dates):
            utc = (date-epoch).days*86400 + (12*60+34-345)*60
            output.write('{} {} {} {} {}\n'.format(date.isoformat(), date.isoweekday(),
                (date-dt.timedelta(days=1)).isoformat(), (date+dt.timedelta(days=1)).isoformat(), utc))
    subprocess.run([sys.argv[1], 'tests/check_dates.lua', str(oracle)],
                   cwd=root, check=True, timeout=30)
