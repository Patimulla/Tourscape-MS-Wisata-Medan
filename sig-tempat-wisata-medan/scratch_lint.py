import os
import re

css_dir = r"c:\Users\Helmonica\website_sig\public\css"
css_files = ["splash.css", "stitch-pages.css", "terra-medan.css", "webgis.css"]

for filename in css_files:
    filepath = os.path.join(css_dir, filename)
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
        
    print(f"=== DETAILED CHECK OF {filename} ===")
    
    # 1. Let's strip comments to avoid false positives
    content_clean = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
    
    # 2. Check for declarations outside curly braces
    # A declaration has the form name: value; but outside of braces, this is invalid
    # Let's find any colon outside of { ... }
    in_braces = 0
    for idx, char in enumerate(content_clean):
        if char == '{':
            in_braces += 1
        elif char == '}':
            in_braces -= 1
        elif char == ':':
            if in_braces == 0:
                # We found a colon outside braces. It could be a pseudo-class like :hover, but let's check
                # pseudo-class selector. If it has a semicolon after it before an open brace, it's suspicious.
                # Let's grab context
                start = max(0, idx - 40)
                end = min(len(content_clean), idx + 40)
                snippet = content_clean[start:end].replace('\n', ' ').strip()
                # If there's a semicolon in the snippet after the colon and before any open brace, it's a declaration outside braces!
                if ';' in content_clean[idx:content_clean.find('{', idx)]:
                    print(f"  [SUSPICIOUS] Colon outside braces around: ... {snippet} ...")

    # 3. Check for declarations inside curly braces that have missing semicolons or double colons
    # Let's extract all rule blocks
    blocks = re.findall(r'\{([^}]+)\}', content_clean)
    for b_idx, block in enumerate(blocks):
        lines = block.split(';')
        for line in lines:
            line = line.strip()
            if not line:
                continue
            # A declaration should have exactly one colon, or maybe URL values with colons
            # e.g. background: url(http://...)
            if ':' not in line:
                # Check if it's not a keyframe percentage or identifier (e.g. "from", "to", "0%", "100%")
                if not re.match(r'^(?:from|to|\d+%)$', line, re.IGNORECASE):
                    print(f"  [WARNING] Rule block has statement without colon: '{line}'")
            else:
                parts = line.split(':', 1)
                prop = parts[0].strip()
                val = parts[1].strip()
                if not prop:
                    print(f"  [ERROR] Empty property name in: '{line}'")
                if not val:
                    print(f"  [ERROR] Empty value in: '{line}'")
                # Check for double colons or suspicious characters
                if prop.count(':') > 0 or ' ' in prop:
                    # check if prop looks like a valid CSS property name (can contain letters, hyphens, prefixes)
                    if not re.match(r'^[\w\-#\.\s,\(\):]+$', prop):
                        print(f"  [ERROR] Suspicious property name: '{prop}' in line '{line}'")
                        
    # 4. Check for double semi-colons or empty rule blocks
    empty_rules = re.findall(r'([^\s{}][^{}]*\{\s*\})', content_clean)
    if empty_rules:
        print(f"  [INFO] Empty rule blocks found: {empty_rules}")
        
    # 5. Let's find any text that could contain bad characters or double-hash
    # e.g. '#ffdbca' has 7 characters, but if a replacement did something like '##ffdbca' or '#ffdbca#ffdbca'
    bad_colors = re.findall(r'#\w+#\w+', content_clean)
    if bad_colors:
        print(f"  [ERROR] Bad color strings: {bad_colors}")

print("Detailed check done!")
