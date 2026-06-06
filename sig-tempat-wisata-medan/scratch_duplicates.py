import os
import re

css_dir = r"c:\Users\Helmonica\website_sig\public\css"
css_files = ["splash.css", "stitch-pages.css", "terra-medan.css", "webgis.css"]

def get_rules(content):
    rules = []
    current_selector = ""
    current_block = ""
    brace_count = 0
    in_comment = False
    
    i = 0
    n = len(content)
    while i < n:
        if content[i:i+2] == "/*":
            in_comment = True
            i += 2
            continue
        if content[i:i+2] == "*/" and in_comment:
            in_comment = False
            i += 2
            continue
        if in_comment:
            i += 1
            continue
            
        char = content[i]
        if char == "{":
            brace_count += 1
            if brace_count == 1:
                pass
            else:
                current_block += char
        elif char == "}":
            brace_count -= 1
            if brace_count == 0:
                rules.append((current_selector.strip(), current_block.strip()))
                current_selector = ""
                current_block = ""
            else:
                current_block += char
        else:
            if brace_count == 0:
                current_selector += char
            else:
                current_block += char
        i += 1
    return rules

def check_block(filename, selector, block):
    declarations = block.split(";")
    seen_props = {}
    for decl in declarations:
        decl = decl.strip()
        if not decl:
            continue
        if ":" not in decl:
            if not re.match(r'^(?:from|to|\d+%)$', decl, re.IGNORECASE):
                print(f"  [{filename}] Block '{selector}' has decl without colon: '{decl}'")
            continue
            
        parts = decl.split(":", 1)
        prop = parts[0].strip().lower()
        val = parts[1].strip()
        
        if prop in seen_props:
            if seen_props[prop] == val:
                print(f"  [{filename}] Block '{selector}' has EXACT DUPLICATE: {prop}: {val}")
            else:
                # We can see if it's fallback
                print(f"  [{filename}] Block '{selector}' has duplicate property: {prop} (first: '{seen_props[prop]}', second: '{val}')")
        else:
            seen_props[prop] = val

for filename in css_files:
    filepath = os.path.join(css_dir, filename)
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
        
    print(f"=== DUPLICATE & SYNTAX CHECK FOR {filename} ===")
    
    rules = get_rules(content)
    for selector, block in rules:
        if not selector:
            continue
            
        if selector.startswith("@media") or selector.startswith("@keyframes") or selector.startswith("@-webkit-keyframes"):
            nested_rules = get_rules(block)
            for ns, nb in nested_rules:
                check_block(filename, f"{selector} -> {ns}", nb)
        else:
            check_block(filename, selector, block)

print("Done check!")
