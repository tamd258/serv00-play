# abcd-serv00-play

这是从 `serv00-play` 精简出来的 abcd 专用安装器。其它项目（sing-box、哪吒、webssh、sun-panel 等）已删除，只保留：

- 自动安装 / 编译 abcd
- 自动申请 serv00 随机 TCP 端口
- 自动创建 proxy 网站
- 自动申请 Let's Encrypt HTTPS
- 自动设置 admin 密码
- 开机自启
- 每 5 分钟保活检测

## 快捷安装

如果你把本目录推到 GitHub 的 `tamd258/serv00-play` 仓库后，可在 serv00 执行：

```sh
bash <(curl -Ls https://raw.githubusercontent.com/tamd258/serv00-play/main/start.sh) --install
```

重新登录后输入：

```sh
ss
```

选择 `1. 安装/重装 abcd`。

也可以一条命令直接安装 abcd：

```sh
bash <(curl -Ls https://raw.githubusercontent.com/tamd258/serv00-play/main/start.sh) --install-abcd
```

## 默认信息

- 程序目录：`~/abcd`
- 源码目录：`~/abcd/src`
- 数据目录：`~/abcd/data`
- 默认管理员账号：`admin`
- 默认管理员密码：`Abcd123!`

安装时会询问域名前缀：

- 输入 `abcd` 会创建 `abcd.<用户名>.serv00.net`
- 输入完整域名如 `abcd.example.com` 会绑定自定义域名（需先把 DNS A 记录指向 serv00 web IP）

## 环境变量

可选：

```sh
ABCD_ADMIN_PASSWORD='你的密码'
ABCD_SOURCE_REPO='https://github.com/tamd258/alist.git'
ABCD_WEB_DIST_URL='https://github.com/AlistGo/alist-web/releases/latest/download/dist.tar.gz'
```

例如：

```sh
ABCD_ADMIN_PASSWORD='abc123456' bash <(curl -Ls https://raw.githubusercontent.com/tamd258/serv00-play/main/start.sh) --install-abcd
```

## 保活

安装后自动写入 crontab：

```cron
@reboot /bin/sh $HOME/bin/abcd_keepalive.sh
*/5 * * * * /bin/sh $HOME/bin/abcd_keepalive.sh
```

保活日志：

```sh
cat ~/abcd/keepalive.log
```
