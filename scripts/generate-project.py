#!/usr/bin/env python3
"""Regenerate the checked-in Xcode project using only Python's standard library.
Not needed for building or running Macventory.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
objects = {}

def uid(key):
    return hashlib.sha256(key.encode()).hexdigest()[:24].upper()

def add(key, value):
    objects[uid(key)] = value
    return uid(key)

def ref(key):
    return uid(key)

def quote(text):
    return json.dumps(str(text), ensure_ascii=False)

def config_list(name, settings):
    refs = []
    for configuration in ["Debug", "Release"]:
        values = dict(settings)
        values.update({"SWIFT_OPTIMIZATION_LEVEL": "-Onone" if configuration == "Debug" else "-O",
                       "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG" if configuration == "Debug" else "",
                       "ENABLE_TESTABILITY": "YES" if configuration == "Debug" else "NO"})
        if configuration == "Release":
            values["SWIFT_COMPILATION_MODE"] = "wholemodule"
        refs.append(add(name + configuration, {"isa": "XCBuildConfiguration", "name": configuration, "buildSettings": values}))
    return add(name + "Configurations", {"isa": "XCConfigurationList", "buildConfigurations": refs, "defaultConfigurationIsVisible": 0, "defaultConfigurationName": "Release"})

def build_file(target, reference):
    return add(target + reference, {"isa": "PBXBuildFile", "fileRef": reference})

source_refs = []
products = []
target_ids = []
for name, directory, product_type, extension in [
    ("MacventoryCore", "Sources/MacventoryCore", "framework", "framework"),
    ("MacventoryPrivilegedHelper", "Sources/MacventoryPrivilegedHelper", "tool", ""),
    ("Macventory", "Sources/Macventory", "application", "app"),
    ("MacventoryTests", "Tests/MacventoryCoreTests", "bundle.unit-test", "xctest"),
    ("MacventoryUITests", "UITests", "bundle.ui-testing", "xctest"),
]:
    files = []
    for path in sorted((ROOT / directory).glob("*.swift")):
        reference = add(str(path.relative_to(ROOT)), {"isa": "PBXFileReference", "lastKnownFileType": "sourcecode.swift", "path": str(path.relative_to(ROOT)), "sourceTree": "SOURCE_ROOT"})
        source_refs.append(reference)
        files.append(build_file(name, reference))
    product = add(name + "Product", {"isa": "PBXFileReference", "explicitFileType": "wrapper.framework" if extension == "framework" else "wrapper.application" if extension == "app" else "compiled.mach-o.executable" if extension == "" else "wrapper.cfbundle", "path": name + ("." + extension if extension else ""), "sourceTree": "BUILT_PRODUCTS_DIR", "includeInIndex": 0})
    products.append(product)
    phases = [add(name + "Sources", {"isa": "PBXSourcesBuildPhase", "buildActionMask": 2147483647, "files": files, "runOnlyForDeploymentPostprocessing": 0})]
    links = []
    dependencies = []
    if name in ["Macventory", "MacventoryTests", "MacventoryPrivilegedHelper"]:
        links.append(build_file(name + "Link", ref("MacventoryCoreProduct")))
        dependencies.append(add(name + "CoreDependency", {"isa": "PBXTargetDependency", "target": ref("MacventoryCoreTarget")}))
    if name in ["MacventoryTests", "MacventoryUITests"]:
        dependencies.append(add(name + "AppDependency", {"isa": "PBXTargetDependency", "target": ref("MacventoryTarget")}))
    phases.append(add(name + "Frameworks", {"isa": "PBXFrameworksBuildPhase", "buildActionMask": 2147483647, "files": links, "runOnlyForDeploymentPostprocessing": 0}))
    resources = []
    if name == "Macventory":
        dependencies.append(add("HelperDependency", {"isa": "PBXTargetDependency", "target": ref("MacventoryPrivilegedHelperTarget")}))
        helper_copy = add("EmbedHelper", {"isa": "PBXBuildFile", "fileRef": ref("MacventoryPrivilegedHelperProduct"), "settings": {"ATTRIBUTES": ["CodeSignOnCopy"]}})
        phases.append(add("EmbedHelperPhase", {"isa": "PBXCopyFilesBuildPhase", "buildActionMask": 2147483647, "dstPath": "", "dstSubfolderSpec": 6, "files": [helper_copy], "name": "Embed MacPorts Helper", "runOnlyForDeploymentPostprocessing": 0}))
        helper_plist = "Resources/Helpers/org.vadimtanel.Macventory.macports-helper.plist"
        helper_ref = add(helper_plist, {"isa": "PBXFileReference", "lastKnownFileType": "text.plist.xml", "path": helper_plist, "sourceTree": "SOURCE_ROOT"})
        source_refs.append(helper_ref)
        phases.append(add("EmbedHelperPlist", {"isa": "PBXCopyFilesBuildPhase", "buildActionMask": 2147483647, "dstPath": "Contents/Library/LaunchDaemons", "dstSubfolderSpec": 1, "files": [build_file("MacventoryHelperPlist", helper_ref)], "name": "Embed Helper Configuration", "runOnlyForDeploymentPostprocessing": 0}))
        embed = add("EmbedCore", {"isa": "PBXBuildFile", "fileRef": ref("MacventoryCoreProduct"), "settings": {"ATTRIBUTES": ["CodeSignOnCopy", "RemoveHeadersOnCopy"]}})
        phases.append(add("EmbedFrameworks", {"isa": "PBXCopyFilesBuildPhase", "buildActionMask": 2147483647, "dstPath": "", "dstSubfolderSpec": 10, "files": [embed], "name": "Embed Frameworks", "runOnlyForDeploymentPostprocessing": 0}))
        for filename in ["LICENSE", "NOTICE", "Resources/Macventory.icns", "Resources/ToolbarMark.png"]:
            reference = add(filename, {"isa": "PBXFileReference", "lastKnownFileType": "image.icns" if filename.endswith(".icns") else "image.png" if filename.endswith(".png") else "text", "path": filename, "sourceTree": "SOURCE_ROOT"})
            source_refs.append(reference)
            resources.append(build_file(name, reference))
    phases.append(add(name + "Resources", {"isa": "PBXResourcesBuildPhase", "buildActionMask": 2147483647, "files": resources, "runOnlyForDeploymentPostprocessing": 0}))
    settings = {"PRODUCT_NAME": "$(TARGET_NAME)", "PRODUCT_BUNDLE_IDENTIFIER": "org.vadimtanel." + name,
                "MACOSX_DEPLOYMENT_TARGET": "13.0", "SWIFT_VERSION": "6.0", "CODE_SIGN_IDENTITY": "-", "CODE_SIGN_STYLE": "Manual",
                "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/../Frameworks", "@loader_path/../Frameworks"],
                "GENERATE_INFOPLIST_FILE": "YES", "ENABLE_APP_SANDBOX": "NO", "SWIFT_STRICT_CONCURRENCY": "complete"}
    if name == "Macventory":
        settings.update({"GENERATE_INFOPLIST_FILE": "NO", "INFOPLIST_FILE": "Resources/Info.plist", "ENABLE_HARDENED_RUNTIME": "YES"})
    if name == "MacventoryPrivilegedHelper":
        settings.update({"PRODUCT_BUNDLE_IDENTIFIER": "org.vadimtanel.Macventory.macports-helper", "CREATE_INFOPLIST_SECTION_IN_BINARY": "YES", "SKIP_INSTALL": "YES", "ENABLE_HARDENED_RUNTIME": "YES"})
    if name == "MacventoryCore":
        settings.update({"DEFINES_MODULE": "YES", "SKIP_INSTALL": "YES", "INSTALL_PATH": "$(LOCAL_LIBRARY_DIR)/Frameworks"})
    if name == "MacventoryTests":
        settings.update({"TEST_HOST": "$(BUILT_PRODUCTS_DIR)/Macventory.app/Contents/MacOS/Macventory", "BUNDLE_LOADER": "$(TEST_HOST)", "MACOSX_DEPLOYMENT_TARGET": "14.0"})
    if name == "MacventoryUITests":
        settings["TEST_TARGET_NAME"] = "Macventory"
    target_ids.append(add(name + "Target", {"isa": "PBXNativeTarget", "buildConfigurationList": config_list(name, settings), "buildPhases": phases, "buildRules": [], "dependencies": dependencies, "name": name, "productName": name, "productReference": product, "productType": "com.apple.product-type." + product_type}))

group = add("MainGroup", {"isa": "PBXGroup", "children": source_refs + [ref("ProductsGroup")], "sourceTree": "<group>"})
add("ProductsGroup", {"isa": "PBXGroup", "children": products, "name": "Products", "sourceTree": "<group>"})
project = add("Project", {"isa": "PBXProject", "attributes": {"BuildIndependentTargetsInParallel": "YES", "LastUpgradeCheck": "1600"}, "buildConfigurationList": config_list("Project", {"SDKROOT": "macosx", "MACOSX_DEPLOYMENT_TARGET": "13.0", "CLANG_ENABLE_MODULES": "YES", "SWIFT_VERSION": "6.0", "ONLY_ACTIVE_ARCH": "YES"}), "compatibilityVersion": "Xcode 14.0", "developmentRegion": "en", "hasScannedForEncodings": 0, "knownRegions": ["en", "Base"], "mainGroup": group, "productRefGroup": ref("ProductsGroup"), "projectDirPath": "", "projectRoot": "", "targets": target_ids})

def serialize(value):
    if isinstance(value, dict):
        return "{\n" + "\n".join(quote(key) + " = " + serialize(v) + ";" for key, v in value.items()) + "\n}"
    if isinstance(value, list):
        return "(" + ", ".join(serialize(v) for v in value) + ")"
    return quote(value)

directory = ROOT / "Macventory.xcodeproj"
directory.mkdir(exist_ok=True)
(directory / "project.pbxproj").write_text("// !$*UTF8*$!\n" + serialize({"archiveVersion": 1, "classes": {}, "objectVersion": 56, "objects": objects, "rootObject": project}) + "\n")
scheme_dir = directory / "xcshareddata/xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)

def target_ref(name):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ref(name + "Target")}" BuildableName="{name}.{"app" if name == "Macventory" else "xctest"}" BlueprintName="{name}" ReferencedContainer="container:Macventory.xcodeproj"/>'

(scheme_dir / "Macventory.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.7">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{target_ref("Macventory")}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="NO"><CommandLineArguments><CommandLineArgument argument="--ui-testing" isEnabled="YES"/></CommandLineArguments><Testables><TestableReference skipped="NO">{target_ref("MacventoryTests")}</TestableReference><TestableReference skipped="NO">{target_ref("MacventoryUITests")}</TestableReference></Testables><MacroExpansion>{target_ref("Macventory")}</MacroExpansion></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="NO"><BuildableProductRunnable runnableDebuggingMode="0">{target_ref("Macventory")}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{target_ref("Macventory")}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print(directory)
