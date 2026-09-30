import os

def fix_imports():
    for root, dirs, files in os.walk('lib'):
        for file in files:
            if file.endswith('.dart'):
                path = os.path.join(root, file)
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                new_content = content.replace(
                    "import 'package:flutter_gen/gen_l10n/app_localizations.dart';",
                    "import 'package:fieldsure_mobile/core/localization/app_localizations.dart';"
                )
                
                # Also replace theme color scheme error getter
                new_content = new_content.replace(
                    "theme.colorScheme.lastError",
                    "theme.colorScheme.error"
                )

                if content != new_content:
                    with open(path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f"Fixed {path}")

if __name__ == '__main__':
    fix_imports()
