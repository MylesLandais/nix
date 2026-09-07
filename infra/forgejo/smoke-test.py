#!/usr/bin/env python3
"""Private integration check; creates and removes uniquely named test accounts/repos."""
import base64
import http.cookiejar
import json
import os
from pathlib import Path
import re
import secrets
import shlex
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

SSH = ['ssh', '-F', '/dev/null', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
       '-o', 'HostKeyAlias=stage-db', 'root@100.123.116.99']
COMPOSE = '/etc/forgejo/compose'

def remote(*args, check=True):
    return subprocess.run(SSH + [shlex.join(args)], text=True, capture_output=True, check=check).stdout.strip()

def cli(*args, check=True):
    return remote(COMPOSE, 'exec', '-T', '-u', '1000', 'forgejo', 'forgejo', '--config',
                  '/etc/gitea/app.ini', 'admin', 'user', *args, check=check)

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

client = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect(),
    urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))

def request(path, method='GET', data=None, auth=None, form=False):
    if path == '/user' or path.startswith(('/admin/', '/repos/', '/user/keys', '/user/repos')):
        path = '/api/v1' + path
    headers = {'Host': 'git.nebula-1.com'}
    if auth:
        headers['Authorization'] = auth
    if data is not None:
        headers['Content-Type'] = 'application/x-www-form-urlencoded' if form else 'application/json'
        if form:
            headers['Origin'] = 'https://git.nebula-1.com'
        data = (urllib.parse.urlencode(data) if form else json.dumps(data)).encode()
    req = urllib.request.Request(base + path, data=data, headers=headers, method=method)
    try:
        response = client.open(req, timeout=20)
    except urllib.error.HTTPError as error:
        response = error
    return response.status, response.read().decode()

def basic(username, password):
    return 'Basic ' + base64.b64encode(f'{username}:{password}'.encode()).decode()

def expect(result, codes):
    status, body = result
    assert status in codes, f'Unexpected HTTP status {status}, expected {codes}'
    return json.loads(body) if body.startswith(('{', '[')) else body

stamp = str(int(time.time()))
admin = 'check-admin-' + stamp
member = 'check-member-' + stamp
outsider = 'check-outsider-' + stamp
password = secrets.token_urlsafe(32)
created = []
passed = False
forward = None
with tempfile.TemporaryDirectory(prefix='forgejo-check-') as scratch:
    scratch = Path(scratch)
    try:
        initially_empty = len(cli('list', '--admin').splitlines()) == 1
        # The public tunnel remains gated while the bootstrap account is pending.
        cli('create', '--admin', '--username', admin, '--email', admin + '@example.invalid',
            '--random-password', '--must-change-password=false')
        created.append(admin)
        token = cli('generate-access-token', '--username', admin, '--token-name', 'integration',
                    '--scopes', 'all', '--raw').splitlines()[-1]
        admin_auth = 'token ' + token
        sock = socket.socket()
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
        sock.close()
        forward = subprocess.Popen(SSH[:-1] + ['-o', 'ExitOnForwardFailure=yes', '-N', '-L',
            f'127.0.0.1:{port}:172.30.42.3:3000', SSH[-1]], stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL)
        base = f'http://127.0.0.1:{port}'
        for _ in range(40):
            try:
                expect(request('/api/healthz'), [200])
                break
            except urllib.error.URLError:
                time.sleep(0.25)
        else:
            raise RuntimeError('SSH forwarding did not become ready')
        expect(request('/explore/repos'), [302, 303])
        page = expect(request('/user/sign_up'), [200])
        csrf = re.search(r'name="_csrf"[^>]*value="([^"]+)"', page)
        expect(request('/user/sign_up', 'POST', {'_csrf': csrf.group(1) if csrf else '', 'user_name': member,
            'email': member + '@example.invalid', 'password': password, 'retype': password}, form=True), [200, 302, 303])
        users = expect(request('/admin/users', auth=admin_auth), [200])
        user = next(u for u in users if u['login'] == member)
        created.append(member)
        assert not user['active'] and not user['is_admin'], 'Signup unexpectedly active or privileged'
        expect(request('/user', auth=basic(member, password)), [401, 403])
        expect(request('/admin/users/' + member, 'PATCH', {'login_name': member, 'source_id': 0,
            'active': True}, admin_auth), [200])
        expect(request('/user', auth=basic(member, password)), [200])
        expect(request('/user/repos', 'POST', {'name': 'probe', 'private': True, 'auto_init': True},
            basic(member, password)), [201])
        expect(request('/admin/users', 'POST', {'username': outsider, 'email': outsider + '@example.invalid',
            'password': password, 'must_change_password': False}, admin_auth), [201])
        created.append(outsider)
        expect(request('/repos/' + member + '/probe', auth=basic(outsider, password)), [403, 404])
        print('PASS: anonymous signup, pending-account denial, admin activation, private repository isolation', flush=True)

        # Test HTTP Git with a PAT privately; public TLS is a separate tunnel check.
        pat = cli('generate-access-token', '--username', member, '--token-name', 'git-check',
                  '--scopes', 'write:repository', '--raw').splitlines()[-1]
        askpass = scratch / 'askpass'
        askpass.write_text('#!/bin/sh\ncase "$1" in *Username*) printf "%s\\n" "$TEST_USER" ;; *) printf "%s\\n" "$TEST_TOKEN" ;; esac\n')
        askpass.chmod(0o700)
        env = dict(os.environ, GIT_ASKPASS=str(askpass), GIT_TERMINAL_PROMPT='0',
                   TEST_USER=member, TEST_TOKEN=pat, GIT_CONFIG_NOSYSTEM='1')
        def git(*args, cwd=scratch):
            return subprocess.run(['git', *args], cwd=cwd, env=env, check=True,
                                  text=True, capture_output=True).stdout.strip()
        git('clone', f'{base}/{member}/probe.git', 'repo')
        repo = scratch / 'repo'
        (repo / 'restore-proof.txt').write_text('Forgejo integration check\n')
        git('add', 'restore-proof.txt', cwd=repo)
        git('-c', 'user.name=Forgejo Check', '-c', 'user.email=check@example.invalid',
            'commit', '-m', 'Verify repository persistence', cwd=repo)
        git('push', cwd=repo)
        revision = git('rev-parse', 'HEAD', cwd=repo)

        key = scratch / 'id_ed25519'
        subprocess.run(['ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-f', str(key)], check=True)
        expect(request('/user/keys', 'POST', {'title': 'integration', 'key': key.with_suffix('.pub').read_text()},
            basic(member, password)), [201])
        # Verify the forge's host key over the already authenticated management SSH connection.
        public = remote(COMPOSE, 'exec', '-T', 'forgejo', 'cat', '/var/lib/gitea/ssh/gitea.rsa.pub')
        known = scratch / 'known_hosts'
        known.write_text('[100.123.116.99]:2222 ' + public + '\n')
        env['GIT_SSH_COMMAND'] = shlex.join(['ssh', '-F', '/dev/null', '-i', str(key), '-o',
            'IdentitiesOnly=yes', '-o', 'IdentityAgent=none', '-o', 'StrictHostKeyChecking=yes',
            '-o', 'UserKnownHostsFile=' + str(known)])
        assert revision in git('ls-remote', f'ssh://git@100.123.116.99:2222/{member}/probe.git')
        print('PASS: Git push using PAT and Git SSH over Tailscale with verified host key', flush=True)
        hashes = remote('sha256sum', '/etc/forgejo/.env.local', '/var/lib/forgejo/conf/app.ini')
        remote('systemctl', 'restart', 'forgejo.service')
        assert hashes == remote('sha256sum', '/etc/forgejo/.env.local', '/var/lib/forgejo/conf/app.ini')
        assert revision in git('ls-remote', f'{base}/{member}/probe.git')
        print('PASS: restart preserves secrets, configuration, accounts, and committed Git history', flush=True)
        remote('systemctl', 'start', 'forgejo-backup.service')
        backup = remote('bash', '-c', 'ls -dt /var/backups/forgejo/forgejo-* | head -1')
        restore = '/var/lib/forgejo-restore-' + stamp
        report = remote('/etc/forgejo/restore-check', backup, restore)
        assert 'Restore check passed' in report
        restored = remote('docker', 'run', '--rm', '--network', 'none', '--user', '1000:1000',
            '-v', restore + '/data:/var/lib/gitea:ro', '--entrypoint', 'git',
            'codeberg.org/forgejo/forgejo:15.0.7-rootless@sha256:1131f4c646d6115577b7cb9ccfe8cd2c289bb54a1e1ed42400be0e22916af924',
            '--git-dir=/var/lib/gitea/git/repositories/' + member + '/probe.git', 'rev-parse', 'HEAD')
        assert restored == revision
        print('PASS: isolated backup restore preserves accounts and exact Git commit', flush=True)
        passed = True
    finally:
        if forward:
            forward.terminate()
            forward.wait(timeout=10)
        cleanup_errors = []
        for username in reversed(created):
            try:
                cli('delete', '--username', username, '--purge')
            except subprocess.CalledProcessError as error:
                if initially_empty and username == admin and 'last admin user' in (error.stdout + error.stderr):
                    # Restore the original empty instance after the fixture: the CLI
                    # protects the last administrator, even when it is a test account.
                    remote(COMPOSE, 'exec', '-T', 'postgres', 'psql', '-U', 'forgejo', '-d', 'forgejo',
                        '-v', 'ON_ERROR_STOP=1', '-c',
                        'UPDATE "user" SET is_admin=false WHERE lower_name = ' + "'" + admin + "';")
                    cli('delete', '--username', username, '--purge')
                else:
                    cleanup_errors.append(username)
        if cleanup_errors:
            raise RuntimeError('Test accounts require cleanup: ' + ', '.join(cleanup_errors))
        print('Temporary test-account cleanup completed', flush=True)
        if passed:
            remote('systemctl', 'start', 'forgejo-backup.service')
            print('Fresh backup taken after test-account cleanup', flush=True)
