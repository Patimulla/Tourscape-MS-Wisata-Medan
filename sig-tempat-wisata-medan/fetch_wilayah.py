import urllib.request
import json
import os

base_url = 'https://emsifa.github.io/api-wilayah-indonesia/api'
cities = ['1271', '1207'] # 1271 is Medan, 1207 is Deli Serdang

result = {}

try:
    for city_id in cities:
        req_obj = urllib.request.Request(f'{base_url}/districts/{city_id}.json', headers={'User-Agent': 'Mozilla/5.0'})
        req = urllib.request.urlopen(req_obj)
        districts = json.loads(req.read().decode('utf-8'))
        
        for d in districts:
            kec_name = d['name']
            req_obj2 = urllib.request.Request(f'{base_url}/villages/{d["id"]}.json', headers={'User-Agent': 'Mozilla/5.0'})
            req2 = urllib.request.urlopen(req_obj2)
            villages = json.loads(req2.read().decode('utf-8'))
            result[kec_name] = [v['name'] for v in villages]

    out_dir = 'd:/Documents/Project Flutter/flutter_wisata_medan/lib/data'
    os.makedirs(out_dir, exist_ok=True)
    out_file = os.path.join(out_dir, 'wilayah_data.dart')

    with open(out_file, 'w', encoding='utf-8') as f:
        f.write('const Map<String, List<String>> wilayahData = {\n')
        for kec, kels in result.items():
            f.write(f'  "{kec}": [\n')
            for kel in kels:
                f.write(f'    "{kel}",\n')
            f.write('  ],\n')
        f.write('};\n')
    print('Done!')
except Exception as e:
    print('Error:', e)
