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

for filename in css_files:
    filepath = os.path.join(css_dir, filename)
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
        
    print(f"=== SELECTORS FOR {filename} ===")
    
    rules = get_rules(content)
    seen_selectors = {}
    
    for selector, block in rules:
        if not selector:
            continue
        # Normalise selector whitespace
        selector_norm = " ".join(selector.split())
        
        # Skip media queries and keyframes from duplicate top-level check, but we can check inside media queries
        if selector_norm.startswith("@media"):
            nested_rules = get_rules(block)
            seen_nested = {}
            for ns, nb in nested_rules:
                ns_norm = " ".join(ns.split())
                if ns_norm in seen_nested:
                    print(f"  [DUPLICATE IN MEDIA] '{ns_norm}' in '{selector_norm}'")
                else:
                    seen_nested[ns_norm] = True
        elif selector_norm.startswith("@keyframes") or selector_norm.startswith("@-webkit-keyframes"):
            pass
        else:
            if selector_norm in seen_selectors:
                print(f"  [DUPLICATE TOP-LEVEL] '{selector_norm}'")
            else:
                seen_selectors[selector_norm] = True

print("Done check!")
