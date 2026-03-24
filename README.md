## Flash SSH (fssh)
fssh (flash ssh) runs commands on many hosts in parallel over SSH. It only needs this script on the control machine; target hosts require no agent.

## Features
- Parallel SSH execution with per-host logs
- Inline commands or command file
- Gray run a single host (or the first host)
- Optional file transfer before execution
- Works with password auth (sshpass) or SSH keys

## Requirements
- bash
- ssh
- sshpass (only for password authentication)

## Quick start
```shell
echo remote_ssh_user=root > .fssh_env
echo remote_ssh_user_pass="your_password" >> .fssh_env
echo remote_ssh_options="-o PasswordAuthentication=yes -o KbdInteractiveAuthentication=yes" >> .fssh_env
curl -fsSL https://raw.githubusercontent.com/xibolun/fssh/refs/heads/master/fssh.sh -o /usr/local/bin/fssh
chmod +x /usr/local/bin/fssh

echo 192.168.0.1 > tmp/ip
echo 192.168.0.2 >> tmp/ip

fssh -i 'uptime' -f tmp/ip
```

## Usage
- Run command file (default): ./fssh.sh
- Run inline command: ./fssh.sh -i 'uptime'
- Use a custom host list: ./fssh.sh -f tmp/ip
- Gray a single host: ./fssh.sh -g 10.0.0.1
- Gray the first host: ./fssh.sh -g
- Transfer a file/dir: ./fssh.sh -s ./local/file -d /tmp
- Transfer then run: ./fssh.sh -s ./local/file -d /tmp -i 'ls -l /tmp'

## Config
.fssh_env example:
remote_ssh_user=root
remote_ssh_user_pass="your_password"
remote_ssh_options="-o PasswordAuthentication=yes -o KbdInteractiveAuthentication=yes"

## Notes
- Logs are written to tmp/<ip>.log.
- If you use SSH keys, leave remote_ssh_user_pass empty.
