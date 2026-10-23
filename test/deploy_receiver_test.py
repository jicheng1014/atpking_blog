import hashlib
import json
import os
import pathlib
import subprocess
import sqlite3
import tempfile
import unittest

class AtomicReleaseTest(unittest.TestCase):
    def test_validation_switch_and_rollback(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            source = pathlib.Path(__file__).parents[1] / 'script/deploy/blog-receive.py'
            receiver = root / 'receiver.py'
            receiver.write_text(source.read_text().replace("ROOT = pathlib.Path('/srv/atpking-blog')", 'ROOT = pathlib.Path(' + repr(temp) + ')'))
            for name in ('old', 'new', 'broken'):
                release = root / 'releases' / name
                manifest = {}
                for page in ('pages/index.p1.m.d.html', 'pages/posts/feed.rss/index.p1.m.d.html'):
                    target = release / page
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_text(name)
                    manifest[page] = hashlib.sha256(name.encode()).hexdigest()
                (release / 'manifest.json').write_text(json.dumps(manifest))
                backup = root / 'backups' / name
                backup.mkdir(parents=True)
                with sqlite3.connect(backup / 'production.sqlite3') as db:
                    db.execute('CREATE TABLE posts(id INTEGER)')
                    db.execute('CREATE TABLE active_storage_blobs(key TEXT, checksum TEXT)')
            def run(command):
                return subprocess.run(['python3', str(receiver)], env={**os.environ, 'SSH_ORIGINAL_COMMAND': command}, capture_output=True)
            self.assertEqual(run('activate old').returncode, 0)
            (root / 'releases/broken/pages/index.p1.m.d.html').write_text('corrupted')
            self.assertNotEqual(run('activate broken').returncode, 0)
            self.assertEqual(os.readlink(root / 'current'), 'releases/old')
            self.assertEqual(run('activate new').returncode, 0)
            self.assertEqual(os.readlink(root / 'previous'), 'releases/old')
            self.assertEqual(run('rollback old').returncode, 0)
            self.assertEqual(os.readlink(root / 'current'), 'releases/old')
            self.assertNotEqual(run('activate ../../etc').returncode, 0)
            self.assertNotEqual(run('rsync --server --sender . /etc/').returncode, 0)

if __name__ == '__main__':
    unittest.main()
