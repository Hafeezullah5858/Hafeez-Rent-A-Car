from pathlib import Path
import re, zipfile, json
root=Path(__file__).resolve().parent
main=(root/'lib/main.dart').read_text()
models=(root/'lib/models/models.dart').read_text()
errors=[]; warnings=[]
# Basic delimiter balance with a small Dart-aware scanner (skips strings/comments).
text=main
stack=[]; pairs={')':'(',']':'[','}':'{'}; opens=set(pairs.values()); i=0; state='code'
while i < len(text):
    ch=text[i]; nxt=text[i+1] if i+1 < len(text) else ''
    if state=='code':
        if ch=='/' and nxt=='/': state='line'; i+=2; continue
        if ch=='/' and nxt=='*': state='block'; i+=2; continue
        if ch in "'\"": state=ch; i+=1; continue
        if ch in opens: stack.append(ch)
        elif ch in pairs:
            if not stack or stack[-1]!=pairs[ch]: errors.append(f'delimiter mismatch near offset {i}: expected {pairs[ch]} got {ch}'); break
            stack.pop()
    elif state=='line':
        if ch=='\n': state='code'
    elif state=='block':
        if ch=='*' and nxt=='/': state='code'; i+=2; continue
    else:
        if ch=='\\': i+=2; continue
        if ch==state: state='code'
    i+=1
if not errors and stack: errors.append('Unclosed delimiters: '+''.join(stack))
# Custom UI handler references
funcs=set(re.findall(r'Future<void>\s+(show\w+)\s*\(',main))
refs=set(re.findall(r'\b(show\w+)\s*\(',main))
missing=sorted(x for x in refs if x.startswith('show') and x not in funcs and x not in {'showDialog','showModalBottomSheet','showDatePicker','showError','showTransactionSuccess','showSnackBar'})
if missing: errors.append('Missing show handlers: '+', '.join(missing))
# Required assets
for p in ['assets/app_icon.png','assets/app_icon.svg']:
    if not (root/p).exists(): errors.append('Missing asset '+p)
# pubspec dependencies used
pub=(root/'pubspec.yaml').read_text()
for dep, token in [('pdf','package:pdf/'),('printing','package:printing/'),('share_plus','package:share_plus/'),('path_provider','package:path_provider/'),('fl_chart','package:fl_chart/')]:
    if token in main and re.search(r'^  '+re.escape(dep)+r':',pub,re.M) is None: errors.append(f'Missing dependency {dep}')
# Report invariants by source inspection
for token in ['vehiclePeriodReport','exportVehiclePeriodCsv','printVehiclePeriodReport','exportVehicleComparisonCsv','printFleetComparison']:
    if token not in main: errors.append('Missing required report function '+token)
# CI checks
wf=root/'.github/workflows/flutter.yml'
if not wf.exists(): errors.append('Missing CI workflow')
else:
    w=wf.read_text()
    for token in ['flutter pub get','flutter analyze','flutter test','flutter build apk --debug']:
        if token not in w: errors.append('CI missing '+token)
# Firestore warning
rules=(root/'firebase/firestore.rules').read_text()
if 'request.auth.uid == userId' not in rules: errors.append('Firestore UID ownership rule missing')
if 'Custom Claims' not in (root/'PREMIUM_V7_4_AUDIT.md').read_text(): warnings.append('Server-side role enforcement remains documented as pending')
# Test quality
if "expect(10, greaterThanOrEqualTo(6))" in (root/'test/models_test.dart').read_text(): warnings.append('Schema test uses a hard-coded weak assertion; it does not read current schema.')
print(json.dumps({'errors':errors,'warnings':warnings,'function_count':len(funcs),'source_bytes':len(main.encode()),'model_bytes':len(models.encode())},indent=2))
raise SystemExit(1 if errors else 0)
