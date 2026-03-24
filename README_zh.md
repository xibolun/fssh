## Flash SSH (fssh)
fssh (flash ssh) 是一个基于 SSH 的并行远程执行脚本，只需在控制端部署脚本，被控端无需安装代理。

## 功能
- 并行 SSH 执行，按主机生成日志
- 支持内联命令或命令文件
- 支持灰度单台（或默认第一台）
- 支持先下发文件再执行
- 支持密码认证（sshpass）或 SSH Key

## 依赖
- bash
- ssh
- sshpass（仅密码认证需要）

## 快速开始
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

## 用法
- 默认执行命令文件：./fssh.sh
- 内联命令：./fssh.sh -i 'uptime'
- 指定主机列表：./fssh.sh -f tmp/ip
- 灰度单台：./fssh.sh -g 10.0.0.1
- 灰度第一台：./fssh.sh -g
- 下发文件/目录：./fssh.sh -s ./local/file -d /tmp
- 下发后执行：./fssh.sh -s ./local/file -d /tmp -i 'ls -l /tmp'

## 配置
.fssh_env 示例：
```
remote_ssh_user=root
remote_ssh_user_pass="your_password"
remote_ssh_options="-o PasswordAuthentication=yes -o KbdInteractiveAuthentication=yes"
```

## 说明
- 日志输出到 tmp/<ip>.log。
- 使用 SSH Key 时可将 remote_ssh_user_pass 留空。
