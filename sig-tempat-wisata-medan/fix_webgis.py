import sys

with open('public/js/webgis.js', 'r', encoding='utf-8') as f:
    content = f.read()

find_str = """    if (resetFilterButton) {
        resetFilterButton.addEventListener('click', resetFilters);
    }
        const openBtn = document.getElementById('btn-open-sidebar');
        sidebar.classList.remove('collapsed');
        openBtn.style.display = 'none';
        setTimeout(() => map.invalidateSize(), 400);
    });"""

replace_str = """    if (resetFilterButton) {
        resetFilterButton.addEventListener('click', resetFilters);
    }

    // My Location
    const btnMyLocation = document.getElementById('btn-my-location');
    if (btnMyLocation) {
        btnMyLocation.addEventListener('click', getUserLocation);
    }

    // Toggle sidebar (close)
    document.getElementById('btn-toggle-sidebar').addEventListener('click', () => {
        const sidebar = document.getElementById('sidebar');
        const openBtn = document.getElementById('btn-open-sidebar');
        sidebar.classList.add('collapsed');
        openBtn.style.display = 'flex';
        setTimeout(() => map.invalidateSize(), 400);
    });

    // Open sidebar (reopen from collapsed)
    document.getElementById('btn-open-sidebar').addEventListener('click', () => {
        const sidebar = document.getElementById('sidebar');
        const openBtn = document.getElementById('btn-open-sidebar');
        sidebar.classList.remove('collapsed');
        openBtn.style.display = 'none';
        setTimeout(() => map.invalidateSize(), 400);
    });"""

if find_str in content:
    content = content.replace(find_str, replace_str)
    with open('public/js/webgis.js', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Fixed.")
else:
    print("Could not find the target string to replace.")
