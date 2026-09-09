#!/usr/bin/env python3
"""Generate the checked-in Xcode project with only Python's standard library."""
from pathlib import Path
import hashlib
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "PersonalGuitarCoach.xcodeproj"
objects = {}

def ident(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()

def obj(object_key, isa, **values):
    key = ident(object_key)
    objects[key] = dict(isa=isa, **values)
    return key

def plist(value, level=0):
    if isinstance(value, dict):
        lines = [json.dumps(str(k)) + " = " + plist(v, level+1) + ";" for k,v in value.items()]
        return "{\n" + "\n".join("\t"*(level+1) + line for line in lines) + "\n" + "\t"*level + "}"
    if isinstance(value, list):
        return "(" + ", ".join(plist(v, level) for v in value) + ")"
    return json.dumps(str(value), ensure_ascii=False)

def file(path, kind):
    return obj("file:" + path, "PBXFileReference", lastKnownFileType=kind, path=path, sourceTree="SOURCE_ROOT")

def build_files(paths, phase):
    return [obj(phase+":"+path, "PBXBuildFile", fileRef=file(path, "sourcecode.swift")) for path in paths]

app_sources = sorted(str(p.relative_to(ROOT)) for p in (ROOT / "App").rglob("*.swift"))
ui_sources = sorted(str(p.relative_to(ROOT)) for p in (ROOT / "Tests/UITests").rglob("*.swift"))
resource_paths = sorted(str(p.relative_to(ROOT)) for p in (ROOT / "Resources").glob("**/*.xcstrings"))
resources = [obj("resource:"+p, "PBXBuildFile", fileRef=file(p, "text.json.xcstrings")) for p in resource_paths]
for directory in ("Resources/Lessons", "Resources/Assets.xcassets"):
    if (ROOT / directory).exists():
        kind = "folder.assetcatalog" if directory.endswith(".xcassets") else "folder"
        resources.append(obj("resource:"+directory, "PBXBuildFile", fileRef=file(directory, kind)))

package = obj("package", "XCLocalSwiftPackageReference", relativePath="Packages/GuitarCoachCore")
manifest = (ROOT / "Packages/GuitarCoachCore/Package.swift").read_text()
product_names = re.findall(r'\.library\(name: "([^"]+)"', manifest)
package_products = [obj("product:"+p, "XCSwiftPackageProductDependency", package=package, productName=p) for p in product_names]
frameworks = [obj("framework:"+p, "PBXBuildFile", productRef=ref) for p,ref in zip(product_names, package_products)]
app_product = obj("app-product", "PBXFileReference", explicitFileType="wrapper.application", path="PersonalGuitarCoach.app", sourceTree="BUILT_PRODUCTS_DIR")
ui_product = obj("ui-product", "PBXFileReference", explicitFileType="wrapper.cfbundle", path="PersonalGuitarCoachUITests.xctest", sourceTree="BUILT_PRODUCTS_DIR")

def phase(name, isa, files):
    return obj(name, isa, buildActionMask="2147483647", files=files, runOnlyForDeploymentPostprocessing="0")

app_phases = [
    phase("app-sources", "PBXSourcesBuildPhase", build_files(app_sources, "app")),
    phase("app-frameworks", "PBXFrameworksBuildPhase", frameworks),
    phase("app-resources", "PBXResourcesBuildPhase", resources),
]
ui_phases = [
    phase("ui-sources", "PBXSourcesBuildPhase", build_files(ui_sources, "ui")),
    phase("ui-frameworks", "PBXFrameworksBuildPhase", []),
    phase("ui-resources", "PBXResourcesBuildPhase", []),
]
common = dict(MACOSX_DEPLOYMENT_TARGET="14.0", SDKROOT="macosx", SWIFT_VERSION="6.0",
              CLANG_ENABLE_MODULES="YES", CLANG_ENABLE_OBJC_ARC="YES", SWIFT_STRICT_CONCURRENCY="complete",
              CODE_SIGN_STYLE="Manual", CODE_SIGN_IDENTITY="-", ENABLE_USER_SCRIPT_SANDBOXING="YES")

def configurations(name, settings):
    refs=[]
    for mode in ("Debug","Release"):
        values = dict(settings)
        values.update(SWIFT_OPTIMIZATION_LEVEL="-Onone" if mode=="Debug" else "-O",
                      DEBUG_INFORMATION_FORMAT="dwarf" if mode=="Debug" else "dwarf-with-dsym")
        if mode=="Debug":
            values.update(SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG", ENABLE_TESTABILITY="YES", ONLY_ACTIVE_ARCH="YES")
        refs.append(obj(name+mode, "XCBuildConfiguration", name=mode, buildSettings=values))
    return obj(name+"configs", "XCConfigurationList", buildConfigurations=refs, defaultConfigurationIsVisible="0", defaultConfigurationName="Release")

project_configs = configurations("project", common)
app_configs = configurations("app", dict(
    PRODUCT_NAME="$(TARGET_NAME)", PRODUCT_BUNDLE_IDENTIFIER="com.valtronforever.PersonalGuitarCoach",
    GENERATE_INFOPLIST_FILE="YES", INFOPLIST_KEY_CFBundleDisplayName="Personal Guitar Coach",
    INFOPLIST_KEY_LSApplicationCategoryType="public.app-category.education",
    INFOPLIST_KEY_NSMicrophoneUsageDescription="Listen to your guitar for tuning and practice feedback.",
    CODE_SIGN_ENTITLEMENTS="App/PersonalGuitarCoach.entitlements", ENABLE_HARDENED_RUNTIME="YES",
    CURRENT_PROJECT_VERSION="1", MARKETING_VERSION="0.1.0", SWIFT_EMIT_LOC_STRINGS="YES",
    LD_RUNPATH_SEARCH_PATHS=["$(inherited)", "@executable_path/../Frameworks"]))
ui_configs = configurations("ui", dict(
    PRODUCT_NAME="$(TARGET_NAME)", PRODUCT_BUNDLE_IDENTIFIER="com.valtronforever.PersonalGuitarCoachUITests",
    GENERATE_INFOPLIST_FILE="YES", TEST_TARGET_NAME="PersonalGuitarCoach"))
proxy = obj("ui-proxy", "PBXContainerItemProxy", containerPortal=ident("project"), proxyType="1", remoteGlobalIDString=ident("app-target"), remoteInfo="PersonalGuitarCoach")
dependency = obj("ui-dependency", "PBXTargetDependency", target=ident("app-target"), targetProxy=proxy)
app_target = obj("app-target", "PBXNativeTarget", name="PersonalGuitarCoach", productName="PersonalGuitarCoach",
                 buildConfigurationList=app_configs, buildPhases=app_phases, buildRules=[], dependencies=[],
                 packageProductDependencies=package_products, productReference=app_product, productType="com.apple.product-type.application")
ui_target = obj("ui-target", "PBXNativeTarget", name="PersonalGuitarCoachUITests", productName="PersonalGuitarCoachUITests",
                buildConfigurationList=ui_configs, buildPhases=ui_phases, buildRules=[], dependencies=[dependency],
                productReference=ui_product, productType="com.apple.product-type.bundle.ui-testing")
source_group = obj("sources-group", "PBXGroup", name="Sources", sourceTree="<group>", children=[ident("file:"+p) for p in app_sources+ui_sources])
resource_group = obj("resources-group", "PBXGroup", name="Resources", sourceTree="<group>", children=[objects[r]["fileRef"] for r in resources])
product_group = obj("products-group", "PBXGroup", name="Products", sourceTree="<group>", children=[app_product,ui_product])
main_group = obj("main-group", "PBXGroup", sourceTree="<group>", children=[source_group,resource_group,product_group])
project_ref = obj("project", "PBXProject", buildConfigurationList=project_configs, compatibilityVersion="Xcode 14.0",
                  developmentRegion="en", knownRegions=["en","uk","Base"], mainGroup=main_group, productRefGroup=product_group,
                  projectDirPath="", projectRoot="", targets=[app_target,ui_target], packageReferences=[package],
                  attributes=dict(LastUpgradeCheck="1600", BuildIndependentTargetsInParallel="YES",
                                  TargetAttributes={ui_target:dict(TestTargetID=app_target)}))
document = dict(archiveVersion="1", classes={}, objectVersion="56", objects=objects, rootObject=project_ref)
project_text = "// !$*UTF8*$!\n" + plist(document) + "\n"
app_reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="PersonalGuitarCoach.app" BlueprintName="PersonalGuitarCoach" ReferencedContainer="container:PersonalGuitarCoach.xcodeproj"/>'
ui_reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ui_target}" BuildableName="PersonalGuitarCoachUITests.xctest" BlueprintName="PersonalGuitarCoachUITests" ReferencedContainer="container:PersonalGuitarCoach.xcodeproj"/>'
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
    <BuildActionEntries>
      <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app_reference}</BuildActionEntry>
    </BuildActionEntries>
  </BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
    <Testables><TestableReference skipped="NO">{ui_reference}</TestableReference></Testables>
  </TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
    <BuildableProductRunnable runnableDebuggingMode="0">{app_reference}</BuildableProductRunnable>
  </LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_reference}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
outputs = {PROJECT / "project.pbxproj":project_text, PROJECT / "xcshareddata/xcschemes/PersonalGuitarCoach.xcscheme":scheme}
for path, text in outputs.items():
    if "--check" in sys.argv:
        if not path.exists() or path.read_text()!=text:
            raise SystemExit(f"Project is stale: run python3 Scripts/generate_project.py ({path.relative_to(ROOT)})")
    else:
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(text)
print("Xcode project is current." if "--check" in sys.argv else "Generated Xcode project and shared scheme.")
