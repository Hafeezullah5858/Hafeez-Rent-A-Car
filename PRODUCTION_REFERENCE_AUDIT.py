import re
from pathlib import Path
p=Path('lib/main.dart')
s=p.read_text()
defs=set(re.findall(r'(?:Future<[^>]+>|void|String|Widget|List<[^>]+>|double|int|bool)\s+(\w+)\s*\(',s))
calls=set(re.findall(r'\b(show[A-Z]\w+)\s*\(',s))
flutter={'showDialog','showDatePicker','showModalBottomSheet','showSnackBar'}
missing=sorted((calls-defs)-flutter)
print('Missing custom show* functions:', missing)
raise SystemExit(1 if missing else 0)
