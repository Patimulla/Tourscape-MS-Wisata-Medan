import 'dart:convert';
import 'dart:io';

void main() async {
  final medanStr = await File('medan.json').readAsString();
  final deliStr = await File('deliserdang.json').readAsString();

  final medanJson = jsonDecode(medanStr);
  final deliJson = jsonDecode(deliStr);

  print('Medan elements: ${medanJson.length}');
  print('Medan type: ${medanJson[0]['geojson']['type']}');
  
  print('Deli elements: ${deliJson.length}');
  print('Deli type: ${deliJson[0]['geojson']['type']}');
}
