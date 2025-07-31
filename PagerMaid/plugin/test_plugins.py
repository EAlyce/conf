"""
自动化插件测试脚本
------------------
扫描 plugin 目录，尝试导入所有插件，检测语法错误。
"""
import os
import importlib.util

PLUGIN_DIR = os.path.join(os.path.dirname(__file__))

for fname in os.listdir(PLUGIN_DIR):
    if fname.endswith('.py') and fname != os.path.basename(__file__):
        path = os.path.join(PLUGIN_DIR, fname)
        spec = importlib.util.spec_from_file_location(fname[:-3], path)
        try:
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            print(f"[OK] {fname}")
        except Exception as e:
            print(f"[FAIL] {fname}: {e}")
