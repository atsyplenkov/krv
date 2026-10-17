import unittest
from unittest.mock import patch
import android_release as release


class VersionChecks(unittest.TestCase):
    def check(self, name='4.5.2+14', tag='v4.5.2', prior='4.5.1+13'):
        def git(*args):
            return 'v4.5.1\nv4.5.2' if args[1] == 'tag' else 'version: ' + prior
        with patch.object(release.Path, 'read_text', return_value='version: ' + name), \
             patch.object(release, 'run', side_effect=git), \
             patch.object(release.subprocess, 'run') as ancestry, \
             patch.dict(release.os.environ, {'GITHUB_REF_TYPE': 'tag', 'GITHUB_REF_NAME': tag}):
            release.validate_version()
            ancestry.assert_called_once_with(['git', 'merge-base', '--is-ancestor', 'HEAD', 'origin/main'], check=True)

    def test_next_release(self):
        self.check()

    def test_tag_mismatch(self):
        with self.assertRaisesRegex(ValueError, 'must match'):
            self.check(tag='v9.9.9')

    def test_reused_build_number(self):
        with self.assertRaisesRegex(ValueError, 'must exceed'):
            self.check(name='4.5.2+13')

    def test_older_version(self):
        with self.assertRaisesRegex(ValueError, 'must exceed'):
            self.check(name='4.4.9+14', tag='v4.4.9')

    def test_malformed_version(self):
        with self.assertRaises(ValueError):
            release.version('version: 4.5.2')

    def test_missing_secrets_fail_before_writing(self):
        with patch.dict(release.os.environ, {}, clear=True), \
             patch.object(release.Path, 'mkdir') as mkdir:
            with self.assertRaisesRegex(ValueError, 'secrets are missing'):
                release.write_signing()
            mkdir.assert_not_called()


if __name__ == '__main__':
    unittest.main()
