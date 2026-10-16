#!/usr/bin/env python3
"""Add a native XCTest UI target to a generated Xcode project (never the game's source project)."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import xml.etree.ElementTree as ET


def attach(project: Path, source: Path) -> None:
    path = project / 'project.pbxproj'
    data = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(path)]))
    objects = data['objects']
    root = objects[data['rootObject']]
    app_id = next(key for key in root['targets'] if objects[key]['productType'] == 'com.apple.product-type.application')
    app = objects[app_id]
    def key(name):
        return hashlib.sha256(('StrahdUITest:' + name).encode()).hexdigest()[:24].upper()
    def obj(name, value):
        objects[key(name)] = value
        return key(name)
    file = obj('source', dict(isa='PBXFileReference', lastKnownFileType='sourcecode.swift', path=str(source.resolve()), sourceTree='<absolute>'))
    build = obj('build', dict(isa='PBXBuildFile', fileRef=file))
    sources = obj('sources', dict(isa='PBXSourcesBuildPhase', buildActionMask='2147483647', files=[build], runOnlyForDeploymentPostprocessing='0'))
    frameworks = obj('frameworks', dict(isa='PBXFrameworksBuildPhase', buildActionMask='2147483647', files=[], runOnlyForDeploymentPostprocessing='0'))
    product = obj('product', dict(isa='PBXFileReference', explicitFileType='wrapper.cfbundle', includeInIndex='0', path='NativeQA.xctest', sourceTree='BUILT_PRODUCTS_DIR'))
    settings = dict(PRODUCT_NAME='$(TARGET_NAME)', PRODUCT_BUNDLE_IDENTIFIER='app.curseofstrahd.uitests',
                    SWIFT_VERSION='5.0', IPHONEOS_DEPLOYMENT_TARGET='16.0', SDKROOT='iphoneos',
                    SUPPORTED_PLATFORMS='iphoneos iphonesimulator', TARGETED_DEVICE_FAMILY='1,2',
                    GENERATE_INFOPLIST_FILE='YES', CODE_SIGNING_ALLOWED='NO', TEST_TARGET_NAME=app['name'],
                    LD_RUNPATH_SEARCH_PATHS=['$(inherited)', '@executable_path/Frameworks', '@loader_path/Frameworks'])
    configurations = [obj(name, dict(isa='XCBuildConfiguration', name=name, buildSettings=settings)) for name in ['Debug','Release']]
    config = obj('config', dict(isa='XCConfigurationList', buildConfigurations=configurations, defaultConfigurationIsVisible='0', defaultConfigurationName='Release'))
    proxy = obj('proxy', dict(isa='PBXContainerItemProxy', containerPortal=data['rootObject'], proxyType='1', remoteGlobalIDString=app_id, remoteInfo=app['name']))
    dependency = obj('dependency', dict(isa='PBXTargetDependency', target=app_id, targetProxy=proxy))
    target = obj('target', dict(isa='PBXNativeTarget', name='NativeQA', productName='NativeQA', productReference=product,
                              productType='com.apple.product-type.bundle.ui-testing', buildConfigurationList=config,
                              buildPhases=[sources,frameworks], buildRules=[], dependencies=[dependency]))
    if target not in root['targets']:
        root['targets'].append(target)
    group = objects[root['mainGroup']]
    for item in [file, product]:
        if item not in group['children']:
            group['children'].append(item)
    root.setdefault('attributes', {}).setdefault('TargetAttributes', {})[target] = {'TestTargetID':app_id, 'CreatedOnToolsVersion':'27.1'}
    path.write_bytes(plistlib.dumps(data))
    scheme = ET.Element('Scheme', LastUpgradeVersion='2710', version='1.3')
    action = ET.SubElement(scheme, 'BuildAction', parallelizeBuildables='YES', buildImplicitDependencies='YES')
    entries = ET.SubElement(action,'BuildActionEntries')
    def ref(parent, id_, name, product_name):
        ET.SubElement(parent,'BuildableReference', BuildableIdentifier='primary', BlueprintIdentifier=id_, BuildableName=product_name,
                      BlueprintName=name, ReferencedContainer='container:' + project.name)
    for id_,name,prod in [(app_id,app['name'],app['name']+'.app'),(target,'NativeQA','NativeQA.xctest')]:
        entry = ET.SubElement(entries,'BuildActionEntry', buildForTesting='YES', buildForRunning='NO', buildForProfiling='NO', buildForArchiving='NO', buildForAnalyzing='YES')
        ref(entry,id_,name,prod)
    test = ET.SubElement(scheme,'TestAction', buildConfiguration='Release', selectedDebuggerIdentifier='', selectedLauncherIdentifier='Xcode.IDEFoundation.Launcher.PosixSpawn', shouldUseLaunchSchemeArgsEnv='YES')
    testable = ET.SubElement(ET.SubElement(test,'Testables'),'TestableReference', skipped='NO', parallelizable='NO')
    ref(testable,target,'NativeQA','NativeQA.xctest')
    destination = project / 'xcshareddata/xcschemes/NativeQA.xcscheme'
    destination.parent.mkdir(parents=True,exist_ok=True)
    ET.ElementTree(scheme).write(destination,encoding='utf-8',xml_declaration=True)


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--project',type=Path,required=True)
    parser.add_argument('--source',type=Path,required=True)
    args=parser.parse_args()
    attach(args.project,args.source)
