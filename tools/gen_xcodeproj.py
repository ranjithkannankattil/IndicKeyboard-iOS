#!/usr/bin/env python3
"""Writes IndicKeyboard.xcodeproj (Xcode 16+ format with synchronized folders)."""
import hashlib, os, re
ROOT = os.path.join(os.path.dirname(__file__), '..')
def oid(name): return hashlib.md5(name.encode()).hexdigest()[:24].upper()

ORG = os.environ.get('BUNDLE_PREFIX', 'com.ranjithkb')
TEAM = os.environ.get('DEVELOPMENT_TEAM', '')
APP, KB, TST = 'IndicKeyboard', 'Keyboard', 'IndicKeyboardTests'
ids = {k: oid(k) for k in [
 'root','main','products','g_app','g_kb','g_shared','g_tests',
 'ref_app','ref_kb','ref_tst','t_app','t_kb','t_tst',
 'src_app','fw_app','res_app','embed','src_kb','fw_kb','res_kb','src_tst','fw_tst','res_tst',
 'bf_appex','proxy_kb','dep_kb','cl_proj','cl_app','cl_kb','cl_tst',
 'c_proj_d','c_proj_r','c_app_d','c_app_r','c_kb_d','c_kb_r','c_tst_d','c_tst_r']}
I = ids

def q(v):
    s = str(v)
    return s if re.fullmatch(r'[A-Za-z0-9_./]+', s) else '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'

def settings(d, indent=4):
    t = '\t' * indent
    out = []
    for k, v in d.items():
        if isinstance(v, list):
            inner = ''.join(f'{t}\t{q(x)},\n' for x in v)
            out.append(f'{t}{k} = (\n{inner}{t});')
        else:
            out.append(f'{t}{k} = {q(v)};')
    return '\n'.join(out)

base = {
 'ALWAYS_SEARCH_USER_PATHS': 'NO', 'CLANG_ENABLE_MODULES': 'YES', 'CLANG_ENABLE_OBJC_ARC': 'YES',
 'COPY_PHASE_STRIP': 'NO', 'ENABLE_STRICT_OBJC_MSGSEND': 'YES',
 'ENABLE_USER_SCRIPT_SANDBOXING': 'YES', 'GCC_C_LANGUAGE_STANDARD': 'gnu17', 'IPHONEOS_DEPLOYMENT_TARGET': '16.0',
 'LOCALIZATION_PREFERS_STRING_CATALOGS': 'YES', 'SDKROOT': 'iphoneos', 'SWIFT_VERSION': '5.0',
}
proj_d = dict(base, DEBUG_INFORMATION_FORMAT='dwarf', ENABLE_TESTABILITY='YES', GCC_OPTIMIZATION_LEVEL='0',
              ONLY_ACTIVE_ARCH='YES', SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG $(inherited)', SWIFT_OPTIMIZATION_LEVEL='-Onone')
proj_r = dict(base, DEBUG_INFORMATION_FORMAT='dwarf-with-dsym', ENABLE_NS_ASSERTIONS='NO',
              SWIFT_COMPILATION_MODE='wholemodule', VALIDATE_PRODUCT='YES')
common_t = {'CODE_SIGN_STYLE': 'Automatic', 'CURRENT_PROJECT_VERSION': '1', 'DEVELOPMENT_TEAM': TEAM,
            'MARKETING_VERSION': '1.0', 'PRODUCT_NAME': '$(TARGET_NAME)', 'TARGETED_DEVICE_FAMILY': '1,2',
            'GENERATE_INFOPLIST_FILE': 'YES', 'SWIFT_EMIT_LOC_STRINGS': 'YES'}
app = dict(common_t, PRODUCT_BUNDLE_IDENTIFIER=f'{ORG}.IndicKeyboard',
           INFOPLIST_KEY_CFBundleDisplayName='Indic Keyboard',
           INFOPLIST_KEY_UIApplicationSceneManifest_Generation='YES',
           INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents='YES',
           INFOPLIST_KEY_UILaunchScreen_Generation='YES',
           INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone='UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight',
           INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad='UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight',
           LD_RUNPATH_SEARCH_PATHS=['$(inherited)', '@executable_path/Frameworks'])
kb = dict(common_t, PRODUCT_BUNDLE_IDENTIFIER=f'{ORG}.IndicKeyboard.Keyboard',
          INFOPLIST_FILE='Config/Keyboard-Info.plist', INFOPLIST_KEY_CFBundleDisplayName='Indic Keyboard',
          APPLICATION_EXTENSION_API_ONLY='YES', SKIP_INSTALL='YES',
          LD_RUNPATH_SEARCH_PATHS=['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks'])
tst = dict(common_t, PRODUCT_BUNDLE_IDENTIFIER=f'{ORG}.IndicKeyboardTests', GENERATE_INFOPLIST_FILE='YES')

def cfg(key, name, d):
    return f'''\t\t{I[key]} /* {name} */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{settings(d)}
\t\t\t}};
\t\t\tname = {name};
\t\t}};\n'''

def phase(key, isa, name):
    return f'\t\t{I[key]} /* {name} */ = {{\n\t\t\tisa = {isa};\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n'

def target(key, name, cl, phases, groups, ref, ptype, deps=()):
    ph = ''.join(f'\t\t\t\t{I[p]},\n' for p in phases)
    gr = ''.join(f'\t\t\t\t{I[g]},\n' for g in groups)
    dp = ''.join(f'\t\t\t\t{I[d]},\n' for d in deps)
    return f'''\t\t{I[key]} /* {name} */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {I[cl]};
\t\t\tbuildPhases = (
{ph}\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
{dp}\t\t\t);
\t\t\tfileSystemSynchronizedGroups = (
{gr}\t\t\t);
\t\t\tname = {name};
\t\t\tpackageProductDependencies = (
\t\t\t);
\t\t\tproductName = {name};
\t\t\tproductReference = {I[ref]};
\t\t\tproductType = "{ptype}";
\t\t}};\n'''

def cl(key, name, a, b):
    return f'\t\t{I[key]} /* Build configuration list for {name} */ = {{\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n\t\t\t\t{I[a]},\n\t\t\t\t{I[b]},\n\t\t\t);\n\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;\n\t\t}};\n'

def sync(key, path):
    return f'\t\t{I[key]} /* {path} */ = {{isa = PBXFileSystemSynchronizedRootGroup; path = {path}; sourceTree = "<group>"; }};\n'

out = f'''// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 77;
\tobjects = {{

/* Begin PBXBuildFile section */
\t\t{I['bf_appex']} /* {KB}.appex in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {I['ref_kb']}; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
\t\t{I['proxy_kb']} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = {I['root']} /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {I['t_kb']};
\t\t\tremoteInfo = {KB};
\t\t}};
/* End PBXContainerItemProxy section */

/* Begin PBXCopyFilesBuildPhase section */
\t\t{I['embed']} /* Embed Foundation Extensions */ = {{
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "";
\t\t\tdstSubfolderSpec = 13;
\t\t\tfiles = (
\t\t\t\t{I['bf_appex']} /* {KB}.appex in Embed Foundation Extensions */,
\t\t\t);
\t\t\tname = "Embed Foundation Extensions";
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXCopyFilesBuildPhase section */

/* Begin PBXFileReference section */
\t\t{I['ref_app']} /* {APP}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {APP}.app; sourceTree = BUILT_PRODUCTS_DIR; }};
\t\t{I['ref_kb']} /* {KB}.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = {KB}.appex; sourceTree = BUILT_PRODUCTS_DIR; }};
\t\t{I['ref_tst']} /* {TST}.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = {TST}.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};
/* End PBXFileReference section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
{sync('g_app','App')}{sync('g_kb','Keyboard')}{sync('g_shared','Shared')}{sync('g_tests','Tests')}/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXFrameworksBuildPhase section */
{phase('fw_app','PBXFrameworksBuildPhase','Frameworks')}{phase('fw_kb','PBXFrameworksBuildPhase','Frameworks')}{phase('fw_tst','PBXFrameworksBuildPhase','Frameworks')}/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t{I['main']} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{I['g_app']} /* App */,
\t\t\t\t{I['g_kb']} /* Keyboard */,
\t\t\t\t{I['g_shared']} /* Shared */,
\t\t\t\t{I['g_tests']} /* Tests */,
\t\t\t\t{I['products']} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{I['products']} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{I['ref_app']} /* {APP}.app */,
\t\t\t\t{I['ref_kb']} /* {KB}.appex */,
\t\t\t\t{I['ref_tst']} /* {TST}.xctest */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
{target('t_app', APP, 'cl_app', ['src_app','fw_app','res_app','embed'], ['g_app','g_shared'], 'ref_app', 'com.apple.product-type.application', ['dep_kb'])}{target('t_kb', KB, 'cl_kb', ['src_kb','fw_kb','res_kb'], ['g_kb','g_shared'], 'ref_kb', 'com.apple.product-type.app-extension')}{target('t_tst', TST, 'cl_tst', ['src_tst','fw_tst','res_tst'], ['g_tests','g_shared'], 'ref_tst', 'com.apple.product-type.bundle.unit-test')}/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{I['root']} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1600;
\t\t\t\tLastUpgradeCheck = 1600;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{I['t_app']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;
\t\t\t\t\t}};
\t\t\t\t\t{I['t_kb']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;
\t\t\t\t\t}};
\t\t\t\t\t{I['t_tst']} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {I['cl_proj']};
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {I['main']};
\t\t\tminimizedProjectReferenceProxies = 1;
\t\t\tpreferredProjectObjectVersion = 77;
\t\t\tproductRefGroup = {I['products']} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{I['t_app']} /* {APP} */,
\t\t\t\t{I['t_kb']} /* {KB} */,
\t\t\t\t{I['t_tst']} /* {TST} */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
{phase('res_app','PBXResourcesBuildPhase','Resources')}{phase('res_kb','PBXResourcesBuildPhase','Resources')}{phase('res_tst','PBXResourcesBuildPhase','Resources')}/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
{phase('src_app','PBXSourcesBuildPhase','Sources')}{phase('src_kb','PBXSourcesBuildPhase','Sources')}{phase('src_tst','PBXSourcesBuildPhase','Sources')}/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
\t\t{I['dep_kb']} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {I['t_kb']} /* {KB} */;
\t\t\ttargetProxy = {I['proxy_kb']} /* PBXContainerItemProxy */;
\t\t}};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
{cfg('c_proj_d','Debug',proj_d)}{cfg('c_proj_r','Release',proj_r)}{cfg('c_app_d','Debug',app)}{cfg('c_app_r','Release',app)}{cfg('c_kb_d','Debug',kb)}{cfg('c_kb_r','Release',kb)}{cfg('c_tst_d','Debug',tst)}{cfg('c_tst_r','Release',tst)}/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
{cl('cl_proj','PBXProject "IndicKeyboard"','c_proj_d','c_proj_r')}{cl('cl_app',APP,'c_app_d','c_app_r')}{cl('cl_kb',KB,'c_kb_d','c_kb_r')}{cl('cl_tst',TST,'c_tst_d','c_tst_r')}/* End XCConfigurationList section */
\t}};
\trootObject = {I['root']} /* Project object */;
}}
'''
d = os.path.join(ROOT, 'IndicKeyboard.xcodeproj')
os.makedirs(d, exist_ok=True)
open(os.path.join(d, 'project.pbxproj'), 'w').write(out)
assert len(set(ids.values())) == len(ids)
print('wrote', os.path.normpath(d))
