# -*- mode: python ; coding: utf-8 -*-
from PyInstaller.utils.hooks import collect_submodules

hiddenimports = ['api', 'core', 'skills', 'backend']
hiddenimports += collect_submodules('api')
hiddenimports += collect_submodules('core')
hiddenimports += collect_submodules('skills')
hiddenimports += collect_submodules('backend')


a = Analysis(
    ['D:\\GitHub\\lazy-tube\\backend\\main.py'],
    pathex=[],
    binaries=[],
    datas=[('frontend\\dist', 'frontend\\dist'), ('backend', 'backend')],
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='Lazy-Tube',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=['D:\\GitHub\\lazy-tube\\frontend\\src\\components\\lazy-tube-ico.ico'],
)
