#!/usr/bin/env python3
"""Generate ZIPTracker.xcodeproj/project.pbxproj for the ZIP Tracker app.

This is a dependency-free generator (Python stdlib only) used because the build
host has no Xcode/XcodeGen. It enumerates the Swift sources under ZIPTracker/ and
Tests/, bundles the ZCTA resource folder (as a folder reference so the in-bundle
`ZCTA/` subdirectory is preserved), links libsqlite3, and wires an app target
plus a unit-test target.

Re-run after adding/removing files:  python3 Scripts/generate_xcodeproj.py
The canonical source of truth is project.yml; this mirrors it.
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT_NAME = "ZIPTracker"
BUNDLE_ID = "com.localfirst.ziptracker"
DEPLOYMENT_TARGET = "17.0"

_counter = [0]
def oid():
    """Deterministic 24-hex object id."""
    _counter[0] += 1
    return "AAAA{:020X}".format(_counter[0])

def swift_files(rel_dir):
    out = []
    base = os.path.join(ROOT, rel_dir)
    for dirpath, _dirs, files in os.walk(base):
        for f in sorted(files):
            if f.endswith(".swift"):
                full = os.path.join(dirpath, f)
                out.append(os.path.relpath(full, ROOT))
    return sorted(out)

app_sources = swift_files("ZIPTracker")
test_sources = swift_files("Tests")

# --- object tables ---
file_refs = {}      # path -> id
build_files = {}     # (path, phase_target) -> id
sections = {"PBXBuildFile": [], "PBXFileReference": [], "PBXGroup": [],
            "PBXSourcesBuildPhase": [], "PBXResourcesBuildPhase": [],
            "PBXFrameworksBuildPhase": [], "PBXNativeTarget": [],
            "PBXProject": [], "PBXContainerItemProxy": [],
            "PBXTargetDependency": [], "XCBuildConfiguration": [],
            "XCConfigurationList": []}

def file_ref(path, explicit_type=None, name=None, source_tree="<group>"):
    if path in file_refs:
        return file_refs[path]
    fid = oid()
    file_refs[path] = fid
    ext = os.path.splitext(path)[1]
    if explicit_type:
        ftype = explicit_type
    elif ext == ".swift":
        ftype = "sourcecode.swift"
    elif ext == ".plist":
        ftype = "text.plist.xml"
    elif ext == ".xcprivacy":
        ftype = "text.plist.xml"
    elif ext == ".sqlite":
        ftype = "file"
    elif ext == ".md":
        ftype = "net.daringfireball.markdown"
    else:
        ftype = "text"
    nm = name or os.path.basename(path)
    sections["PBXFileReference"].append(
        f'\t\t{fid} /* {nm} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; '
        f'name = "{nm}"; path = "{path}"; sourceTree = "{source_tree}"; }};'
    )
    return fid

def build_file(ref_id, name, tag):
    bid = oid()
    sections["PBXBuildFile"].append(
        f'\t\t{bid} /* {name} in {tag} */ = {{isa = PBXBuildFile; fileRef = {ref_id} /* {name} */; }};'
    )
    return bid

# --- product references ---
app_product = oid()
sections["PBXFileReference"].append(
    f'\t\t{app_product} /* {PROJECT_NAME}.app */ = {{isa = PBXFileReference; explicitFileType = '
    f'"wrapper.application"; includeInIndex = 0; path = "{PROJECT_NAME}.app"; sourceTree = BUILT_PRODUCTS_DIR; }};'
)
test_product = oid()
sections["PBXFileReference"].append(
    f'\t\t{test_product} /* {PROJECT_NAME}Tests.xctest */ = {{isa = PBXFileReference; explicitFileType = '
    f'"wrapper.cfbundle"; includeInIndex = 0; path = "{PROJECT_NAME}Tests.xctest"; sourceTree = BUILT_PRODUCTS_DIR; }};'
)

# --- resources ---
info_plist_ref = file_ref("ZIPTracker/Resources/Info.plist")
xcprivacy_ref = file_ref("ZIPTracker/Resources/PrivacyInfo.xcprivacy")
# Asset catalog (compiled by actool: AppIcon, AccentColor, launch assets).
assets_ref = file_ref("ZIPTracker/Resources/Assets.xcassets",
                      explicit_type="folder.assetcatalog", name="Assets.xcassets")
# Folder reference so the on-disk ZCTA/ directory is copied preserving structure.
zcta_folder_ref = oid()
file_refs["ZIPTracker/Resources/ZCTA"] = zcta_folder_ref
sections["PBXFileReference"].append(
    f'\t\t{zcta_folder_ref} /* ZCTA */ = {{isa = PBXFileReference; lastKnownFileType = folder; '
    f'name = ZCTA; path = "ZIPTracker/Resources/ZCTA"; sourceTree = "<group>"; }};'
)
# Test bundle gets the sample DB directly.
sample_db_ref = file_ref("ZIPTracker/Resources/ZCTA/zcta_sample.sqlite",
                         name="zcta_sample.sqlite")

# --- app sources build files ---
app_src_bf = []
for p in app_sources:
    rid = file_ref(p)
    app_src_bf.append(build_file(rid, os.path.basename(p), "Sources"))

# --- app resources build files ---
app_res_bf = []
app_res_bf.append(build_file(assets_ref, "Assets.xcassets", "Resources"))
app_res_bf.append(build_file(xcprivacy_ref, "PrivacyInfo.xcprivacy", "Resources"))
app_res_bf.append(build_file(zcta_folder_ref, "ZCTA", "Resources"))

# --- test sources build files ---
test_src_bf = []
for p in test_sources:
    rid = file_ref(p)
    test_src_bf.append(build_file(rid, os.path.basename(p), "Sources"))
test_res_bf = [build_file(sample_db_ref, "zcta_sample.sqlite", "Resources")]

# --- build phases ---
def phase(isa, name, file_ids):
    pid = oid()
    body = "\n".join(f"\t\t\t\t{i} /* {name} */," for i in file_ids)
    sections[isa].append(
        f"\t\t{pid} /* {name} */ = {{\n"
        f"\t\t\tisa = {isa};\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n{body}\n\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};"
    )
    return pid

app_sources_phase = phase("PBXSourcesBuildPhase", "Sources", app_src_bf)
app_resources_phase = phase("PBXResourcesBuildPhase", "Resources", app_res_bf)
app_frameworks_phase = phase("PBXFrameworksBuildPhase", "Frameworks", [])
test_sources_phase = phase("PBXSourcesBuildPhase", "Sources", test_src_bf)
test_resources_phase = phase("PBXResourcesBuildPhase", "Resources", test_res_bf)
test_frameworks_phase = phase("PBXFrameworksBuildPhase", "Frameworks", [])

# --- groups ---
def group(name, children, path=None):
    gid = oid()
    body = "\n".join(f"\t\t\t\t{c} /* {n} */," for c, n in children)
    path_line = f'\t\t\tpath = "{path}";\n' if path else ""
    name_line = f'\t\t\tname = "{name}";\n' if name else ""
    sections["PBXGroup"].append(
        f"\t\t{gid} /* {name or 'group'} */ = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n{body}\n\t\t\t);\n"
        f"{name_line}{path_line}"
        f'\t\t\tsourceTree = "<group>";\n'
        f"\t\t}};"
    )
    return gid

# Flat groups by directory for navigability.
by_dir = {}
for p in app_sources:
    d = os.path.dirname(p)
    by_dir.setdefault(d, []).append(p)

dir_group_ids = []
for d in sorted(by_dir):
    children = [(file_refs[p], os.path.basename(p)) for p in sorted(by_dir[d])]
    gid = group(os.path.basename(d) or d, children)
    dir_group_ids.append((gid, os.path.basename(d) or d))

resources_group = group("Resources", [
    (info_plist_ref, "Info.plist"),
    (assets_ref, "Assets.xcassets"),
    (xcprivacy_ref, "PrivacyInfo.xcprivacy"),
    (zcta_folder_ref, "ZCTA"),
])
app_group = group(PROJECT_NAME, dir_group_ids + [(resources_group, "Resources")])

test_children = [(file_refs[p], os.path.basename(p)) for p in test_sources]
test_group = group("Tests", test_children)

products_group = group("Products", [
    (app_product, f"{PROJECT_NAME}.app"),
    (test_product, f"{PROJECT_NAME}Tests.xctest"),
])
main_group = group(None, [
    (app_group, PROJECT_NAME),
    (test_group, "Tests"),
    (products_group, "Products"),
])

# --- build configurations ---
def build_config(name, settings):
    cid = oid()
    lines = "\n".join(f'\t\t\t\t{k} = {v};' for k, v in settings.items())
    sections["XCBuildConfiguration"].append(
        f"\t\t{cid} /* {name} */ = {{\n"
        f"\t\t\tisa = XCBuildConfiguration;\n"
        f"\t\t\tbuildSettings = {{\n{lines}\n\t\t\t}};\n"
        f"\t\t\tname = {name};\n"
        f"\t\t}};"
    )
    return cid

def config_list(name, debug_id, release_id):
    lid = oid()
    sections["XCConfigurationList"].append(
        f"\t\t{lid} /* Build configuration list for {name} */ = {{\n"
        f"\t\t\tisa = XCConfigurationList;\n"
        f"\t\t\tbuildConfigurations = (\n"
        f"\t\t\t\t{debug_id} /* Debug */,\n"
        f"\t\t\t\t{release_id} /* Release */,\n"
        f"\t\t\t);\n"
        f"\t\t\tdefaultConfigurationIsVisible = 0;\n"
        f"\t\t\tdefaultConfigurationName = Release;\n"
        f"\t\t}};"
    )
    return lid

project_common = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu11",
    "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
    "SDKROOT": "iphoneos",
    "SWIFT_VERSION": "5.0",
    "MARKETING_VERSION": "1.0",
    "CURRENT_PROJECT_VERSION": "1",
}
proj_debug = build_config("Debug", {**project_common,
    "ENABLE_TESTABILITY": "YES",
    "GCC_PREPROCESSOR_DEFINITIONS": '"DEBUG=1 $(inherited)"',
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": '"DEBUG $(inherited)"',
    "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"',
    "ONLY_ACTIVE_ARCH": "YES",
})
proj_release = build_config("Release", {**project_common,
    "SWIFT_OPTIMIZATION_LEVEL": '"-O"',
    "VALIDATE_PRODUCT": "YES",
})
proj_config_list = config_list(f'PBXProject "{PROJECT_NAME}"', proj_debug, proj_release)

app_common = {
    "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
    "PRODUCT_NAME": '"$(TARGET_NAME)"',
    "INFOPLIST_FILE": "ZIPTracker/Resources/Info.plist",
    "GENERATE_INFOPLIST_FILE": "NO",
    # iPhone-only until iPad layouts are verified.
    "TARGETED_DEVICE_FAMILY": '"1"',
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "OTHER_LDFLAGS": '"-lsqlite3"',
    "CODE_SIGN_STYLE": "Automatic",
    "CODE_SIGNING_ALLOWED": "NO",
    "ENABLE_PREVIEWS": "YES",
}
app_debug = build_config("Debug", app_common)
app_release = build_config("Release", app_common)
app_config_list = config_list(f'PBXNativeTarget "{PROJECT_NAME}"', app_debug, app_release)

test_common = {
    "PRODUCT_BUNDLE_IDENTIFIER": f"{BUNDLE_ID}Tests",
    "PRODUCT_NAME": '"$(TARGET_NAME)"',
    "GENERATE_INFOPLIST_FILE": "YES",
    "TARGETED_DEVICE_FAMILY": '"1"',
    "TEST_HOST": f'"$(BUILT_PRODUCTS_DIR)/{PROJECT_NAME}.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/{PROJECT_NAME}"',
    "BUNDLE_LOADER": "$(TEST_HOST)",
    "CODE_SIGN_STYLE": "Automatic",
    "CODE_SIGNING_ALLOWED": "NO",
}
test_debug = build_config("Debug", test_common)
test_release = build_config("Release", test_common)
test_config_list = config_list(f'PBXNativeTarget "{PROJECT_NAME}Tests"', test_debug, test_release)

# --- targets ---
app_target = oid()
test_target = oid()

sections["PBXNativeTarget"].append(
    f"\t\t{app_target} /* {PROJECT_NAME} */ = {{\n"
    f"\t\t\tisa = PBXNativeTarget;\n"
    f"\t\t\tbuildConfigurationList = {app_config_list} /* Build configuration list for PBXNativeTarget \"{PROJECT_NAME}\" */;\n"
    f"\t\t\tbuildPhases = (\n"
    f"\t\t\t\t{app_sources_phase} /* Sources */,\n"
    f"\t\t\t\t{app_frameworks_phase} /* Frameworks */,\n"
    f"\t\t\t\t{app_resources_phase} /* Resources */,\n"
    f"\t\t\t);\n"
    f"\t\t\tbuildRules = ();\n"
    f"\t\t\tdependencies = ();\n"
    f"\t\t\tname = {PROJECT_NAME};\n"
    f"\t\t\tproductName = {PROJECT_NAME};\n"
    f"\t\t\tproductReference = {app_product} /* {PROJECT_NAME}.app */;\n"
    f"\t\t\tproductType = \"com.apple.product-type.application\";\n"
    f"\t\t}};"
)

# test depends on app
container_proxy = oid()
sections["PBXContainerItemProxy"].append(
    f"\t\t{container_proxy} /* PBXContainerItemProxy */ = {{\n"
    f"\t\t\tisa = PBXContainerItemProxy;\n"
    f"\t\t\tcontainerPortal = PROJECT_OBJECT /* Project object */;\n"
    f"\t\t\tproxyType = 1;\n"
    f"\t\t\tremoteGlobalIDString = {app_target};\n"
    f"\t\t\tremoteInfo = {PROJECT_NAME};\n"
    f"\t\t}};"
)
target_dep = oid()
sections["PBXTargetDependency"].append(
    f"\t\t{target_dep} /* PBXTargetDependency */ = {{\n"
    f"\t\t\tisa = PBXTargetDependency;\n"
    f"\t\t\ttarget = {app_target} /* {PROJECT_NAME} */;\n"
    f"\t\t\ttargetProxy = {container_proxy} /* PBXContainerItemProxy */;\n"
    f"\t\t}};"
)

sections["PBXNativeTarget"].append(
    f"\t\t{test_target} /* {PROJECT_NAME}Tests */ = {{\n"
    f"\t\t\tisa = PBXNativeTarget;\n"
    f"\t\t\tbuildConfigurationList = {test_config_list} /* Build configuration list for PBXNativeTarget \"{PROJECT_NAME}Tests\" */;\n"
    f"\t\t\tbuildPhases = (\n"
    f"\t\t\t\t{test_sources_phase} /* Sources */,\n"
    f"\t\t\t\t{test_frameworks_phase} /* Frameworks */,\n"
    f"\t\t\t\t{test_resources_phase} /* Resources */,\n"
    f"\t\t\t);\n"
    f"\t\t\tbuildRules = ();\n"
    f"\t\t\tdependencies = (\n\t\t\t\t{target_dep} /* PBXTargetDependency */,\n\t\t\t);\n"
    f"\t\t\tname = {PROJECT_NAME}Tests;\n"
    f"\t\t\tproductName = {PROJECT_NAME}Tests;\n"
    f"\t\t\tproductReference = {test_product} /* {PROJECT_NAME}Tests.xctest */;\n"
    f"\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";\n"
    f"\t\t}};"
)

# --- project object ---
project_obj = "PROJECT_OBJECT"
sections["PBXProject"].append(
    f"\t\t{project_obj} /* Project object */ = {{\n"
    f"\t\t\tisa = PBXProject;\n"
    f"\t\t\tattributes = {{\n"
    f"\t\t\t\tLastSwiftUpdateCheck = 1700;\n"
    f"\t\t\t\tLastUpgradeCheck = 1700;\n"
    f"\t\t\t\tTargetAttributes = {{\n"
    f"\t\t\t\t\t{app_target} = {{CreatedOnToolsVersion = 17.0;}};\n"
    f"\t\t\t\t\t{test_target} = {{CreatedOnToolsVersion = 17.0; TestTargetID = {app_target};}};\n"
    f"\t\t\t\t}};\n"
    f"\t\t\t}};\n"
    f"\t\t\tbuildConfigurationList = {proj_config_list} /* Build configuration list for PBXProject \"{PROJECT_NAME}\" */;\n"
    f"\t\t\tcompatibilityVersion = \"Xcode 15.0\";\n"
    f"\t\t\tdevelopmentRegion = en;\n"
    f"\t\t\thasScannedForEncodings = 0;\n"
    f"\t\t\tknownRegions = (\n\t\t\t\ten,\n\t\t\t\tBase,\n\t\t\t);\n"
    f"\t\t\tmainGroup = {main_group};\n"
    f"\t\t\tproductRefGroup = {products_group} /* Products */;\n"
    f"\t\t\tprojectDirPath = \"\";\n"
    f"\t\t\tprojectRoot = \"\";\n"
    f"\t\t\ttargets = (\n\t\t\t\t{app_target} /* {PROJECT_NAME} */,\n\t\t\t\t{test_target} /* {PROJECT_NAME}Tests */,\n\t\t\t);\n"
    f"\t\t}};"
)

# --- assemble ---
order = ["PBXBuildFile", "PBXContainerItemProxy", "PBXFileReference",
         "PBXFrameworksBuildPhase", "PBXGroup", "PBXNativeTarget", "PBXProject",
         "PBXResourcesBuildPhase", "PBXSourcesBuildPhase", "PBXTargetDependency",
         "XCBuildConfiguration", "XCConfigurationList"]

out = ["// !$*UTF8*$!", "{", "\tarchiveVersion = 1;", "\tclasses = {};",
       "\tobjectVersion = 56;", "\tobjects = {"]
for sec in order:
    out.append(f"\n/* Begin {sec} section */")
    for entry in sections[sec]:
        out.append(entry)
    out.append(f"/* End {sec} section */")
out.append("\t};")
out.append(f"\trootObject = {project_obj} /* Project object */;")
out.append("}")

text = "\n".join(out).replace("PROJECT_OBJECT", oid_project := "AAAA000000000000DEADBEEF")
# Re-point references to the project object placeholder.
proj_dir = os.path.join(ROOT, f"{PROJECT_NAME}.xcodeproj")
os.makedirs(proj_dir, exist_ok=True)
with open(os.path.join(proj_dir, "project.pbxproj"), "w") as f:
    f.write(text + "\n")

# Minimal shared scheme so ⌘U / xcodebuild test works out of the box.
schemes_dir = os.path.join(proj_dir, "xcshareddata", "xcschemes")
os.makedirs(schemes_dir, exist_ok=True)
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1700" version="1.7">
   <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
            <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="{PROJECT_NAME}.app" BlueprintName="{PROJECT_NAME}" ReferencedContainer="container:{PROJECT_NAME}.xcodeproj"></BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
      <Testables>
         <TestableReference skipped="NO">
            <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{test_target}" BuildableName="{PROJECT_NAME}Tests.xctest" BlueprintName="{PROJECT_NAME}Tests" ReferencedContainer="container:{PROJECT_NAME}.xcodeproj"></BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="{PROJECT_NAME}.app" BlueprintName="{PROJECT_NAME}" ReferencedContainer="container:{PROJECT_NAME}.xcodeproj"></BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration="Release"></ProfileAction>
   <AnalyzeAction buildConfiguration="Debug"></AnalyzeAction>
   <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"></ArchiveAction>
</Scheme>
'''
with open(os.path.join(schemes_dir, f"{PROJECT_NAME}.xcscheme"), "w") as f:
    f.write(scheme)

print(f"Generated {proj_dir}")
print(f"  app sources: {len(app_sources)}  test sources: {len(test_sources)}")
