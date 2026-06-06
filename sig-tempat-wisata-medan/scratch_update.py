import os

# 1. Update Routes
routes_path = r'c:\Users\Helmonica\website_sig\app\Config\Routes.php'
with open(routes_path, 'r', encoding='utf-8') as f:
    content = f.read()
content = content.replace("'/beranda'", "'/explore'")
with open(routes_path, 'w', encoding='utf-8') as f:
    f.write(content)

# 2. Update Views
views_dir = r'c:\Users\Helmonica\website_sig\app\Views'
for root, _, files in os.walk(views_dir):
    for file in files:
        if file.endswith('.php'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Replacements for 'Beranda' to 'Explore'
            content = content.replace('href="/beranda"', 'href="/explore"')
            content = content.replace('>Beranda<', '>Explore<')
            
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)

# 3. Add CSS for Photo Aspect Ratio
admin_css_path = r'c:\Users\Helmonica\website_sig\public\css\admin.css'
webgis_css_path = r'c:\Users\Helmonica\website_sig\public\css\webgis.css'
stitch_css_path = r'c:\Users\Helmonica\website_sig\public\css\stitch-pages.css'

css_to_add = '''
/* Fix Detail Photo Aspect Ratio */
.detail-gallery {
    display: flex;
    gap: 12px;
    overflow-x: auto;
    padding-bottom: 12px;
}
.detail-foto {
    flex: 0 0 auto;
    width: 100%;
    max-width: 320px;
    aspect-ratio: 4/3;
    object-fit: cover;
    border-radius: 12px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.1);
}
@media (min-width: 768px) {
    .detail-foto {
        max-width: 480px;
        aspect-ratio: 16/9;
    }
}
'''

for css_path in [admin_css_path, webgis_css_path]:
    if os.path.exists(css_path):
        with open(css_path, 'a', encoding='utf-8') as f:
            f.write(css_to_add)

if os.path.exists(stitch_css_path):
    with open(stitch_css_path, 'r', encoding='utf-8') as f:
        stitch_content = f.read()
    # Increase height of detail-hero
    stitch_content = stitch_content.replace('min-height: 240px;', 'min-height: 400px;')
    stitch_content = stitch_content.replace('min-height: 280px;', 'min-height: 400px;')
    with open(stitch_css_path, 'w', encoding='utf-8') as f:
        f.write(stitch_content)

print('Updated Beranda to Explore and fixed photo aspect ratios.')
