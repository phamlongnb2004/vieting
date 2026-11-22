"""Sinh lại packages/phosphor_flutter/lib/phosphor_flutter.dart từ các icon Phosphor đang dùng trong lib/.
Cần bản clone https://github.com/phosphor-icons/flutter (đường dẫn qua biến PHOSPHOR_SRC).
Tác giả: Phạm Thành Long (thlong)"""
import glob, os, re

src = os.environ.get('PHOSPHOR_SRC', '/home/claude/phosphor-icons/flutter') + '/lib/src/'
used = {}
for f in glob.glob('lib/**/*.dart', recursive=True):
    for st, n in re.findall(r'PhosphorIcons(Regular|Fill|Bold)\.(\w+)', open(f, encoding='utf-8').read()):
        used.setdefault(st, set()).add(n)
out = ['// Biểu tượng Phosphor (MIT, phosphoricons.com) — bản rút gọn chỉ gồm icon VieTing dùng.',
       '// Sinh bằng tools/gen_icons.py. IconData là final class nên không kế thừa được, dùng IconData thẳng.', '',
       "import 'package:flutter/widgets.dart';", '']
for st in ['Bold', 'Fill', 'Regular']:
    names = used.get(st, set())
    code = open(src + f'phosphor_icons_{st.lower()}.dart', encoding='utf-8').read()
    out += [f'class PhosphorIcons{st} {{', f'  const PhosphorIcons{st}._();']
    for n in sorted(names):
        m = re.search(r'static const ' + n + r' = PhosphorFlatIconData\((0x[0-9a-fA-F]+)', code)
        if not m:
            raise SystemExit(f'Không có icon {st}.{n}')
        out.append(f"  static const IconData {n} = IconData({m.group(1)}, fontFamily: 'Phosphor{st}', fontPackage: 'phosphor_flutter');")
    out += ['}', '']
open('packages/phosphor_flutter/lib/phosphor_flutter.dart', 'w', encoding='utf-8').write('\n'.join(out))
print({k: len(v) for k, v in used.items()})
