#!/usr/bin/env python3
"""Generate the checked-in Klyp Xcode project without external dependencies."""

from __future__ import annotations

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT_DIR = ROOT / "Klyp.xcodeproj"
PROJECT_DIR.mkdir(parents=True, exist_ok=True)


def uid(key: str) -> str:
    return hashlib.sha1(key.encode("utf-8")).hexdigest()[:24].upper()


app_files = sorted(
    str(path.relative_to(ROOT)).replace("\\", "/")
    for path in (ROOT / "Klyp").rglob("*.swift")
)
test_files = sorted(
    str(path.relative_to(ROOT)).replace("\\", "/")
    for path in (ROOT / "KlypTests").rglob("*.swift")
)

app_target = uid("target:Klyp")
test_target = uid("target:KlypTests")
project_id = uid("project:Klyp")
main_group = uid("group:main")
app_group = uid("group:app")
models_group = uid("group:app:Models")
services_group = uid("group:app:Services")
support_group = uid("group:app:Support")
viewmodels_group = uid("group:app:ViewModels")
views_group = uid("group:app:Views")
tests_group = uid("group:tests")
products_group = uid("group:products")
docs_group = uid("group:docs")
frameworks_group = uid("group:frameworks")

app_product = uid("product:Klyp.app")
test_product = uid("product:KlypTests.xctest")

app_sources_phase = uid("phase:app:sources")
app_frameworks_phase = uid("phase:app:frameworks")
app_resources_phase = uid("phase:app:resources")
test_sources_phase = uid("phase:test:sources")
test_frameworks_phase = uid("phase:test:frameworks")
test_resources_phase = uid("phase:test:resources")

target_dependency = uid("dependency:test->app")
container_proxy = uid("proxy:test->app")

project_config_list = uid("configlist:project")
app_config_list = uid("configlist:app")
test_config_list = uid("configlist:test")

project_debug = uid("config:project:debug")
project_release = uid("config:project:release")
app_debug = uid("config:app:debug")
app_release = uid("config:app:release")
test_debug = uid("config:test:debug")
test_release = uid("config:test:release")

file_refs: dict[str, str] = {}
build_files: dict[tuple[str, str], str] = {}

for path in app_files + test_files + [
    "Klyp/Info.plist",
    "Klyp/Klyp.entitlements",
    "README.md",
]:
    file_refs[path] = uid(f"file:{path}")

for path in app_files:
    build_files[("app", path)] = uid(f"build:app:{path}")
for path in test_files:
    build_files[("test", path)] = uid(f"build:test:{path}")

security_framework = uid("framework:Security")
service_management_framework = uid("framework:ServiceManagement")
security_build = uid("build:framework:Security")
service_management_build = uid("build:framework:ServiceManagement")


def q(value: str) -> str:
    return f'"{value}"'


def child_lines(paths: list[str], indent: str = "\t\t\t") -> str:
    return "\n".join(
        f"{indent}{file_refs[path]} /* {Path(path).name} */," for path in paths
    )


root_app_files = [p for p in app_files if len(Path(p).parts) == 2]
models_files = [p for p in app_files if "/Models/" in p]
services_files = [p for p in app_files if "/Services/" in p]
support_files = [p for p in app_files if "/Support/" in p]
viewmodel_files = [p for p in app_files if "/ViewModels/" in p]
views_files = [p for p in app_files if "/Views/" in p]

lines: list[str] = []
add = lines.append
add("// !$*UTF8*$!")
add("{")
add("\tarchiveVersion = 1;")
add("\tclasses = {};")
add("\tobjectVersion = 60;")
add("\tobjects = {")

add("\n/* Begin PBXBuildFile section */")
for path in app_files:
    add(
        f"\t\t{build_files[('app', path)]} /* {Path(path).name} in Sources */ = "
        f"{{isa = PBXBuildFile; fileRef = {file_refs[path]} /* {Path(path).name} */; }};"
    )
for path in test_files:
    add(
        f"\t\t{build_files[('test', path)]} /* {Path(path).name} in Sources */ = "
        f"{{isa = PBXBuildFile; fileRef = {file_refs[path]} /* {Path(path).name} */; }};"
    )
add(
    f"\t\t{security_build} /* Security.framework in Frameworks */ = "
    f"{{isa = PBXBuildFile; fileRef = {security_framework} /* Security.framework */; }};"
)
add(
    f"\t\t{service_management_build} /* ServiceManagement.framework in Frameworks */ = "
    f"{{isa = PBXBuildFile; fileRef = {service_management_framework} /* ServiceManagement.framework */; }};"
)
add("/* End PBXBuildFile section */")

add("\n/* Begin PBXContainerItemProxy section */")
add(f"\t\t{container_proxy} /* PBXContainerItemProxy */ = {{")
add("\t\t\tisa = PBXContainerItemProxy;")
add(f"\t\t\tcontainerPortal = {project_id} /* Project object */;")
add("\t\t\tproxyType = 1;")
add(f"\t\t\tremoteGlobalIDString = {app_target};")
add("\t\t\tremoteInfo = Klyp;")
add("\t\t};")
add("/* End PBXContainerItemProxy section */")

add("\n/* Begin PBXFileReference section */")
for path in app_files + test_files:
    add(
        f"\t\t{file_refs[path]} /* {Path(path).name} */ = "
        f"{{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(Path(path).name)}; sourceTree = \"<group>\"; }};"
    )
add(
    f"\t\t{file_refs['Klyp/Info.plist']} /* Info.plist */ = "
    "{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; };"
)
add(
    f"\t\t{file_refs['Klyp/Klyp.entitlements']} /* Klyp.entitlements */ = "
    "{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Klyp.entitlements; sourceTree = \"<group>\"; };"
)
for doc in ["README.md"]:
    add(
        f"\t\t{file_refs[doc]} /* {doc} */ = "
        f"{{isa = PBXFileReference; lastKnownFileType = net.daringfireball.markdown; path = {doc}; sourceTree = \"<group>\"; }};"
    )
add(
    f"\t\t{security_framework} /* Security.framework */ = "
    "{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = Security.framework; path = System/Library/Frameworks/Security.framework; sourceTree = SDKROOT; };"
)
add(
    f"\t\t{service_management_framework} /* ServiceManagement.framework */ = "
    "{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = ServiceManagement.framework; path = System/Library/Frameworks/ServiceManagement.framework; sourceTree = SDKROOT; };"
)
add(
    f"\t\t{app_product} /* Klyp.app */ = "
    "{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Klyp.app; sourceTree = BUILT_PRODUCTS_DIR; };"
)
add(
    f"\t\t{test_product} /* KlypTests.xctest */ = "
    "{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = KlypTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };"
)
add("/* End PBXFileReference section */")

add("\n/* Begin PBXFrameworksBuildPhase section */")
add(f"\t\t{app_frameworks_phase} /* Frameworks */ = {{")
add("\t\t\tisa = PBXFrameworksBuildPhase;")
add("\t\t\tbuildActionMask = 2147483647;")
add("\t\t\tfiles = (")
add(f"\t\t\t\t{security_build} /* Security.framework in Frameworks */,")
add(f"\t\t\t\t{service_management_build} /* ServiceManagement.framework in Frameworks */,")
add("\t\t\t);")
add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
add("\t\t};")
add(f"\t\t{test_frameworks_phase} /* Frameworks */ = {{")
add("\t\t\tisa = PBXFrameworksBuildPhase;")
add("\t\t\tbuildActionMask = 2147483647;")
add("\t\t\tfiles = ();")
add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
add("\t\t};")
add("/* End PBXFrameworksBuildPhase section */")

add("\n/* Begin PBXGroup section */")
add(f"\t\t{main_group} = {{")
add("\t\t\tisa = PBXGroup;")
add("\t\t\tchildren = (")
add(f"\t\t\t\t{app_group} /* Klyp */,")
add(f"\t\t\t\t{tests_group} /* KlypTests */,")
add(f"\t\t\t\t{docs_group} /* Documentation */,")
add(f"\t\t\t\t{frameworks_group} /* Frameworks */,")
add(f"\t\t\t\t{products_group} /* Products */,")
add("\t\t\t);")
add("\t\t\tsourceTree = \"<group>\";")
add("\t\t};")

add(f"\t\t{app_group} /* Klyp */ = {{")
add("\t\t\tisa = PBXGroup;")
add("\t\t\tchildren = (")
for path in root_app_files:
    add(f"\t\t\t\t{file_refs[path]} /* {Path(path).name} */,")
add(f"\t\t\t\t{models_group} /* Models */,")
add(f"\t\t\t\t{services_group} /* Services */,")
add(f"\t\t\t\t{support_group} /* Support */,")
add(f"\t\t\t\t{viewmodels_group} /* ViewModels */,")
add(f"\t\t\t\t{views_group} /* Views */,")
add(f"\t\t\t\t{file_refs['Klyp/Info.plist']} /* Info.plist */,")
add(f"\t\t\t\t{file_refs['Klyp/Klyp.entitlements']} /* Klyp.entitlements */,")
add("\t\t\t);")
add("\t\t\tpath = Klyp;")
add("\t\t\tsourceTree = \"<group>\";")
add("\t\t};")

for group_id, name, paths in [
    (models_group, "Models", models_files),
    (services_group, "Services", services_files),
    (support_group, "Support", support_files),
    (viewmodels_group, "ViewModels", viewmodel_files),
    (views_group, "Views", views_files),
]:
    add(f"\t\t{group_id} /* {name} */ = {{")
    add("\t\t\tisa = PBXGroup;")
    add("\t\t\tchildren = (")
    for path in paths:
        add(f"\t\t\t\t{file_refs[path]} /* {Path(path).name} */,")
    add("\t\t\t);")
    add(f"\t\t\tpath = {name};")
    add("\t\t\tsourceTree = \"<group>\";")
    add("\t\t};")

add(f"\t\t{tests_group} /* KlypTests */ = {{")
add("\t\t\tisa = PBXGroup;")
add("\t\t\tchildren = (")
for path in test_files:
    add(f"\t\t\t\t{file_refs[path]} /* {Path(path).name} */,")
add("\t\t\t);")
add("\t\t\tpath = KlypTests;")
add("\t\t\tsourceTree = \"<group>\";")
add("\t\t};")

add(f"\t\t{docs_group} /* Documentation */ = {{")
add("\t\t\tisa = PBXGroup;")
add("\t\t\tchildren = (")
for doc in ["README.md"]:
    add(f"\t\t\t\t{file_refs[doc]} /* {doc} */,")
add("\t\t\t);")
add("\t\t\tname = Documentation;")
add("\t\t\tsourceTree = \"<group>\";")
add("\t\t};")

add(f"\t\t{frameworks_group} /* Frameworks */ = {{")
add("\t\t\tisa = PBXGroup;")
add("\t\t\tchildren = (")
add(f"\t\t\t\t{security_framework} /* Security.framework */,")
add(f"\t\t\t\t{service_management_framework} /* ServiceManagement.framework */,")
add("\t\t\t);")
add("\t\t\tname = Frameworks;")
add("\t\t\tsourceTree = \"<group>\";")
add("\t\t};")

add(f"\t\t{products_group} /* Products */ = {{")
add("\t\t\tisa = PBXGroup;")
add("\t\t\tchildren = (")
add(f"\t\t\t\t{app_product} /* Klyp.app */,")
add(f"\t\t\t\t{test_product} /* KlypTests.xctest */,")
add("\t\t\t);")
add("\t\t\tname = Products;")
add("\t\t\tsourceTree = \"<group>\";")
add("\t\t};")
add("/* End PBXGroup section */")

add("\n/* Begin PBXNativeTarget section */")
add(f"\t\t{app_target} /* Klyp */ = {{")
add("\t\t\tisa = PBXNativeTarget;")
add(f"\t\t\tbuildConfigurationList = {app_config_list} /* Build configuration list for PBXNativeTarget \"Klyp\" */;")
add("\t\t\tbuildPhases = (")
add(f"\t\t\t\t{app_sources_phase} /* Sources */,")
add(f"\t\t\t\t{app_frameworks_phase} /* Frameworks */,")
add(f"\t\t\t\t{app_resources_phase} /* Resources */,")
add("\t\t\t);")
add("\t\t\tbuildRules = ();")
add("\t\t\tdependencies = ();")
add("\t\t\tname = Klyp;")
add("\t\t\tproductName = Klyp;")
add(f"\t\t\tproductReference = {app_product} /* Klyp.app */;")
add("\t\t\tproductType = \"com.apple.product-type.application\";")
add("\t\t};")

add(f"\t\t{test_target} /* KlypTests */ = {{")
add("\t\t\tisa = PBXNativeTarget;")
add(f"\t\t\tbuildConfigurationList = {test_config_list} /* Build configuration list for PBXNativeTarget \"KlypTests\" */;")
add("\t\t\tbuildPhases = (")
add(f"\t\t\t\t{test_sources_phase} /* Sources */,")
add(f"\t\t\t\t{test_frameworks_phase} /* Frameworks */,")
add(f"\t\t\t\t{test_resources_phase} /* Resources */,")
add("\t\t\t);")
add("\t\t\tbuildRules = ();")
add("\t\t\tdependencies = (")
add(f"\t\t\t\t{target_dependency} /* PBXTargetDependency */,")
add("\t\t\t);")
add("\t\t\tname = KlypTests;")
add("\t\t\tproductName = KlypTests;")
add(f"\t\t\tproductReference = {test_product} /* KlypTests.xctest */;")
add("\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";")
add("\t\t};")
add("/* End PBXNativeTarget section */")

add("\n/* Begin PBXProject section */")
add(f"\t\t{project_id} /* Project object */ = {{")
add("\t\t\tisa = PBXProject;")
add("\t\t\tattributes = {")
add("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
add("\t\t\t\tLastSwiftUpdateCheck = 1600;")
add("\t\t\t\tLastUpgradeCheck = 1600;")
add("\t\t\t\tTargetAttributes = {")
add(f"\t\t\t\t\t{app_target} = {{")
add("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
add("\t\t\t\t\t\tSystemCapabilities = {")
add("\t\t\t\t\t\t\tcom.apple.Keychain = { enabled = 1; };")
add("\t\t\t\t\t\t};")
add("\t\t\t\t\t};")
add(f"\t\t\t\t\t{test_target} = {{ CreatedOnToolsVersion = 16.0; TestTargetID = {app_target}; }};")
add("\t\t\t\t};")
add("\t\t\t};")
add(f"\t\t\tbuildConfigurationList = {project_config_list} /* Build configuration list for PBXProject \"Klyp\" */;")
add("\t\t\tcompatibilityVersion = \"Xcode 15.0\";")
add("\t\t\tdevelopmentRegion = ru;")
add("\t\t\thasScannedForEncodings = 0;")
add("\t\t\tknownRegions = (ru, en, Base);")
add(f"\t\t\tmainGroup = {main_group};")
add(f"\t\t\tproductRefGroup = {products_group} /* Products */;")
add("\t\t\tprojectDirPath = \"\";")
add("\t\t\tprojectRoot = \"\";")
add("\t\t\ttargets = (")
add(f"\t\t\t\t{app_target} /* Klyp */,")
add(f"\t\t\t\t{test_target} /* KlypTests */,")
add("\t\t\t);")
add("\t\t};")
add("/* End PBXProject section */")

add("\n/* Begin PBXResourcesBuildPhase section */")
for phase in [app_resources_phase, test_resources_phase]:
    add(f"\t\t{phase} /* Resources */ = {{")
    add("\t\t\tisa = PBXResourcesBuildPhase;")
    add("\t\t\tbuildActionMask = 2147483647;")
    add("\t\t\tfiles = ();")
    add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    add("\t\t};")
add("/* End PBXResourcesBuildPhase section */")

add("\n/* Begin PBXSourcesBuildPhase section */")
add(f"\t\t{app_sources_phase} /* Sources */ = {{")
add("\t\t\tisa = PBXSourcesBuildPhase;")
add("\t\t\tbuildActionMask = 2147483647;")
add("\t\t\tfiles = (")
for path in app_files:
    add(f"\t\t\t\t{build_files[('app', path)]} /* {Path(path).name} in Sources */,")
add("\t\t\t);")
add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
add("\t\t};")
add(f"\t\t{test_sources_phase} /* Sources */ = {{")
add("\t\t\tisa = PBXSourcesBuildPhase;")
add("\t\t\tbuildActionMask = 2147483647;")
add("\t\t\tfiles = (")
for path in test_files:
    add(f"\t\t\t\t{build_files[('test', path)]} /* {Path(path).name} in Sources */,")
add("\t\t\t);")
add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
add("\t\t};")
add("/* End PBXSourcesBuildPhase section */")

add("\n/* Begin PBXTargetDependency section */")
add(f"\t\t{target_dependency} /* PBXTargetDependency */ = {{")
add("\t\t\tisa = PBXTargetDependency;")
add(f"\t\t\ttarget = {app_target} /* Klyp */;")
add(f"\t\t\ttargetProxy = {container_proxy} /* PBXContainerItemProxy */;")
add("\t\t};")
add("/* End PBXTargetDependency section */")


def add_config(config_id: str, name: str, settings: dict[str, str | int]) -> None:
    add(f"\t\t{config_id} /* {name} */ = {{")
    add("\t\t\tisa = XCBuildConfiguration;")
    add("\t\t\tbuildSettings = {")
    for key, value in settings.items():
        if isinstance(value, int):
            rendered = str(value)
        elif value.startswith("(") or value in {"YES", "NO"}:
            rendered = value
        else:
            rendered = q(value)
        add(f"\t\t\t\t{key} = {rendered};")
    add("\t\t\t};")
    add(f"\t\t\tname = {name};")
    add("\t\t};")


add("\n/* Begin XCBuildConfiguration section */")
project_common = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION": "YES_AGGRESSIVE",
    "CLANG_CXX_LANGUAGE_STANDARD": "gnu++20",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": "YES",
    "CLANG_WARN_BOOL_CONVERSION": "YES",
    "CLANG_WARN_COMMA": "YES",
    "CLANG_WARN_CONSTANT_CONVERSION": "YES",
    "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS": "YES",
    "CLANG_WARN_DIRECT_OBJC_ISA_USAGE": "YES_ERROR",
    "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
    "CLANG_WARN_EMPTY_BODY": "YES",
    "CLANG_WARN_ENUM_CONVERSION": "YES",
    "CLANG_WARN_INFINITE_RECURSION": "YES",
    "CLANG_WARN_INT_CONVERSION": "YES",
    "CLANG_WARN_NON_LITERAL_NULL_CONVERSION": "YES",
    "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF": "YES",
    "CLANG_WARN_OBJC_LITERAL_CONVERSION": "YES",
    "CLANG_WARN_OBJC_ROOT_CLASS": "YES_ERROR",
    "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": "YES",
    "CLANG_WARN_RANGE_LOOP_ANALYSIS": "YES",
    "CLANG_WARN_STRICT_PROTOTYPES": "YES",
    "CLANG_WARN_SUSPICIOUS_MOVE": "YES",
    "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE",
    "CLANG_WARN_UNREACHABLE_CODE": "YES",
    "CLANG_WARN__DUPLICATE_METHOD_MATCH": "YES",
    "COPY_PHASE_STRIP": "NO",
    "DEAD_CODE_STRIPPING": "YES",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "GCC_WARN_64_TO_32_BIT_CONVERSION": "YES",
    "GCC_WARN_ABOUT_RETURN_TYPE": "YES_ERROR",
    "GCC_WARN_UNDECLARED_SELECTOR": "YES",
    "GCC_WARN_UNINITIALIZED_AUTOS": "YES_AGGRESSIVE",
    "GCC_WARN_UNUSED_FUNCTION": "YES",
    "GCC_WARN_UNUSED_VARIABLE": "YES",
    "MACOSX_DEPLOYMENT_TARGET": "13.0",
    "SDKROOT": "macosx",
}
project_debug_settings = dict(project_common)
project_debug_settings.update(
    {
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_TESTABILITY": "YES",
        "GCC_OPTIMIZATION_LEVEL": "0",
        "ONLY_ACTIVE_ARCH": "YES",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)",
        "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
    }
)
project_release_settings = dict(project_common)
project_release_settings.update(
    {
        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
        "ENABLE_NS_ASSERTIONS": "NO",
        "MTL_ENABLE_DEBUG_INFO": "NO",
        "ONLY_ACTIVE_ARCH": "NO",
        "SWIFT_COMPILATION_MODE": "wholemodule",
    }
)
add_config(project_debug, "Debug", project_debug_settings)
add_config(project_release, "Release", project_release_settings)

app_common = {
    "CODE_SIGN_ENTITLEMENTS": "Klyp/Klyp.entitlements",
    "CODE_SIGN_STYLE": "Automatic",
    "COMBINE_HIDPI_IMAGES": "YES",
    "CURRENT_PROJECT_VERSION": 1,
    "ENABLE_APP_SANDBOX": "YES",
    "ENABLE_HARDENED_RUNTIME": "YES",
    "GENERATE_INFOPLIST_FILE": "NO",
    "INFOPLIST_FILE": "Klyp/Info.plist",
    "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/../Frameworks",
    "MARKETING_VERSION": "1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.creadone.Klyp",
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SWIFT_EMIT_LOC_STRINGS": "NO",
    "SWIFT_STRICT_CONCURRENCY": "complete",
    "SWIFT_VERSION": "5.0",
}
add_config(app_debug, "Debug", app_common)
add_config(app_release, "Release", app_common)

test_common = {
    "BUNDLE_LOADER": "$(TEST_HOST)",
    "CODE_SIGN_STYLE": "Automatic",
    "GENERATE_INFOPLIST_FILE": "YES",
    "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.creadone.KlypTests",
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SWIFT_STRICT_CONCURRENCY": "complete",
    "SWIFT_VERSION": "5.0",
    "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/Klyp.app/Contents/MacOS/Klyp",
}
add_config(test_debug, "Debug", test_common)
add_config(test_release, "Release", test_common)
add("/* End XCBuildConfiguration section */")

add("\n/* Begin XCConfigurationList section */")
for config_list, configs, comment in [
    (project_config_list, [project_debug, project_release], 'PBXProject "Klyp"'),
    (app_config_list, [app_debug, app_release], 'PBXNativeTarget "Klyp"'),
    (test_config_list, [test_debug, test_release], 'PBXNativeTarget "KlypTests"'),
]:
    add(f"\t\t{config_list} /* Build configuration list for {comment} */ = {{")
    add("\t\t\tisa = XCConfigurationList;")
    add("\t\t\tbuildConfigurations = (")
    add(f"\t\t\t\t{configs[0]} /* Debug */,")
    add(f"\t\t\t\t{configs[1]} /* Release */,")
    add("\t\t\t);")
    add("\t\t\tdefaultConfigurationIsVisible = 0;")
    add("\t\t\tdefaultConfigurationName = Release;")
    add("\t\t};")
add("/* End XCConfigurationList section */")

add("\t};")
add(f"\trootObject = {project_id} /* Project object */;")
add("}")

(PROJECT_DIR / "project.pbxproj").write_text("\n".join(lines) + "\n", encoding="utf-8")

scheme_dir = PROJECT_DIR / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES"
      buildArchitectures = "Automatic">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{app_target}"
               BuildableName = "Klyp.app"
               BlueprintName = "Klyp"
               ReferencedContainer = "container:Klyp.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "NO"
            buildForProfiling = "NO"
            buildForArchiving = "NO"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{test_target}"
               BuildableName = "KlypTests.xctest"
               BlueprintName = "KlypTests"
               ReferencedContainer = "container:Klyp.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
      <Testables>
         <TestableReference skipped = "NO" parallelizable = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{test_target}"
               BuildableName = "KlypTests.xctest"
               BlueprintName = "KlypTests"
               ReferencedContainer = "container:Klyp.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
      <MacroExpansion>
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target}"
            BuildableName = "Klyp.app"
            BlueprintName = "Klyp"
            ReferencedContainer = "container:Klyp.xcodeproj">
         </BuildableReference>
      </MacroExpansion>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target}"
            BuildableName = "Klyp.app"
            BlueprintName = "Klyp"
            ReferencedContainer = "container:Klyp.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target}"
            BuildableName = "Klyp.app"
            BlueprintName = "Klyp"
            ReferencedContainer = "container:Klyp.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
'''
(scheme_dir / "Klyp.xcscheme").write_text(scheme, encoding="utf-8")
