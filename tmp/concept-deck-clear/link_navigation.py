from collections import defaultdict
import json
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from lxml import etree

folder = Path(__file__).resolve().parent
source = folder / 'draft.pptx'
target = folder / 'linked.pptx'
navigation = json.loads((folder / 'navigation.json').read_text(encoding='utf-8'))
groups = defaultdict(list)
for link in navigation:
    groups[link['slide']].append(link)

draw = 'http://schemas.openxmlformats.org/drawingml/2006/main'
pres = 'http://schemas.openxmlformats.org/presentationml/2006/main'
office = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
rels = 'http://schemas.openxmlformats.org/package/2006/relationships'

with ZipFile(source) as base:
    patches = {}
    for number, items in groups.items():
        slide_path = f'ppt/slides/slide{number}.xml'
        rel_path = f'ppt/slides/_rels/slide{number}.xml.rels'
        slide = etree.fromstring(base.read(slide_path))
        rel = etree.fromstring(base.read(rel_path))
        occupied = {child.get('Id') for child in rel}
        shapes = {node.get('name'): node for node in slide.iter(f'{{{pres}}}cNvPr')}
        for i, item in enumerate(items, 1):
            id_ = f'rIdAlgorythmNav{i}'
            assert id_ not in occupied
            assert f'ppt/slides/slide{item["target"]}.xml' in base.namelist()
            node = shapes[item['key']]
            click = etree.Element(f'{{{draw}}}hlinkClick')
            click.set(f'{{{office}}}id', id_)
            click.set('action', 'ppaction://hlinksldjump')
            node.insert(0, click)
            etree.SubElement(rel, f'{{{rels}}}Relationship', Id=id_,
                Type=office+'/slide', Target=f'slide{item["target"]}.xml')
        patches[slide_path] = etree.tostring(slide, encoding='UTF-8', xml_declaration=True, standalone=True)
        patches[rel_path] = etree.tostring(rel, encoding='UTF-8', xml_declaration=True, standalone=True)
    with ZipFile(target, 'w', ZIP_DEFLATED) as out:
        for name in base.namelist():
            out.writestr(name, patches[name] if name in patches else base.read(name))

def verify(path):
    with ZipFile(path) as deck:
        for number, items in groups.items():
            slide = etree.fromstring(deck.read(f'ppt/slides/slide{number}.xml'))
            rel = etree.fromstring(deck.read(f'ppt/slides/_rels/slide{number}.xml.rels'))
            by_id = {child.get('Id'): child for child in rel}
            shapes = {node.get('name'): node for node in slide.iter(f'{{{pres}}}cNvPr')}
            for item in items:
                click = shapes[item['key']].find(f'{{{draw}}}hlinkClick')
                assert click.get('action') == 'ppaction://hlinksldjump'
                node = by_id[click.get(f'{{{office}}}id')]
                assert node.get('Type') == office+'/slide'
                assert node.get('Target') == f'slide{item["target"]}.xml'
                assert not node.get('TargetMode')
        print(f'{len(navigation)} internal links verified in {path.name}')

if __name__ == '__main__':
    import sys
    verify(Path(sys.argv[1]) if len(sys.argv) > 1 else target)
