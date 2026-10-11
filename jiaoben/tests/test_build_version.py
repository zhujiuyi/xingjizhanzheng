"""Prevent a verified PCK from being delivered with stale Windows version metadata."""
from pathlib import Path
import sys
import unittest
from unittest import mock
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import build_client as b

class BuildVersion(unittest.TestCase):
 def test_normalize_and_reject_non_windows_version(self):
  self.assertEqual(b.windows_numeric_version('0.22.0'),'0.22.0.0')
  for value in ('v0.22.0','0.22.0-rc1','1.2.3.4.5','1.70000'):
   with self.assertRaises(ValueError):b.windows_numeric_version(value)
 def test_stale_export_preset_is_rejected_before_export(self):
  text='application/file_version="0.21.0.0"\napplication/product_version="0.21.0.0"\n'
  with self.assertRaisesRegex(ValueError,'must match project'):b.check_windows_preset_version(text,'0.22.0')
  self.assertEqual(b.check_windows_preset_version(text.replace('0.21','0.22'),'0.22.0'),'0.22.0.0')
 def test_missing_product_version_is_rejected(self):
  with self.assertRaisesRegex(ValueError,'product_version'):b.check_windows_preset_version('application/file_version="0.22.0.0"','0.22.0')
 @unittest.skipUnless(b.os.name=='nt','native Windows inspection wrapper')
 def test_exported_metadata_mismatch_is_rejected(self):
  result=mock.Mock(returncode=0,stdout=b'{"FileVersion":"0.21.0.0","ProductVersion":"0.21.0.0"}',stderr=b'')
  with mock.patch.object(b.subprocess,'run',return_value=result):
   with self.assertRaisesRegex(RuntimeError,'version differs'):b.inspect_windows_binary_version(Path('client.exe'),'0.22.0.0')
if __name__=='__main__':unittest.main()
