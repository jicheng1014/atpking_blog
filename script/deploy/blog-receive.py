#!/usr/bin/env python3
"""Forced SSH command for the blog publisher; no shell, forwarding, or arbitrary paths."""
import base64, hashlib, json, os, pathlib, re, shlex, sqlite3, sys
ROOT = pathlib.Path('/srv/atpking-blog')
args = shlex.split(os.environ.get('SSH_ORIGINAL_COMMAND', ''))
if args[:2] == ['rsync', '--server']:
    dest = pathlib.Path(args[-1])
    if '..' in dest.parts or not any(dest.is_relative_to(ROOT / p) for p in ('releases', 'backups')):
        sys.exit('Invalid destination')
    if '--sender' in args or any(x.startswith(('--rsync-path', '--rsh', '--remove-source-files')) for x in args):
        sys.exit('Invalid rsync mode')
    dest.mkdir(parents=True, exist_ok=True)
    os.execv('/usr/bin/rsync', args)
elif len(args) == 2 and args[0] in ('activate', 'rollback') and re.fullmatch(r'[a-zA-Z0-9_-]+', args[1]):
    release = ROOT / 'releases' / args[1]
    manifest = json.loads((release / 'manifest.json').read_text())
    for name, checksum in manifest.items():
        file = release / name
        if pathlib.PurePosixPath(name).is_absolute() or '..' in pathlib.PurePosixPath(name).parts or file.is_symlink():
            sys.exit('Unsafe release path')
        if hashlib.sha256(file.read_bytes()).hexdigest() != checksum:
            sys.exit('Release checksum mismatch: ' + name)
    if not (release / 'pages/index.p1.m.d.html').is_file() or not (release / 'pages/posts/feed.rss/index.p1.m.d.html').is_file():
        sys.exit('Incomplete release')
    if args[0] == 'activate':
        backup = ROOT / 'backups' / args[1] / 'production.sqlite3'
        with sqlite3.connect('file:' + str(backup) + '?mode=ro', uri=True) as db:
            if db.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
                sys.exit('Invalid database snapshot')
            for key, checksum in db.execute('SELECT key, checksum FROM active_storage_blobs'):
                if not re.fullmatch(r'[a-zA-Z0-9_-]+', key):
                    sys.exit('Invalid storage key')
                image = ROOT / 'backups/originals' / key[:2] / key[2:4] / key
                if not image.is_file() or base64.b64encode(hashlib.md5(image.read_bytes()).digest()).decode() != checksum:
                    sys.exit('Image backup missing or corrupt: ' + key)
    current = ROOT / 'current'
    if current.is_symlink():
        old = os.readlink(current)
        temp = ROOT / 'previous.next'
        temp.unlink(missing_ok=True)
        temp.symlink_to(old)
        temp.replace(ROOT / 'previous')
    temp = ROOT / 'current.next'
    temp.unlink(missing_ok=True)
    temp.symlink_to('releases/' + args[1])
    temp.replace(current)
    print('Activated ' + args[1])
else:
    sys.exit('Command not allowed')
