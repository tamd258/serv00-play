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

在 serv00 执行：

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
- 默认管理员密码：安装时随机生成并显示；也可用 `ABCD_ADMIN_PASSWORD` 指定

安装时会询问域名前缀：

- 输入 `abcd` 会创建 `abcd.<用户名>.serv00.net`
- 输入完整域名如 `abcd.example.com` 会绑定自定义域名（需先把 DNS A 记录指向 serv00 web IP）

## 环境变量

可选：

```sh
ABCD_ADMIN_PASSWORD='你的密码'        # 不设置则随机生成
ABCD_KEEP_DATA=1                    # 可选：重装时保留旧 data 目录；默认会备份并清空旧数据
ABCD_SOURCE_REPO='https://github.com/tamd258/alist.git'
ABCD_WEB_DIST_URL='https://github.com/AlistGo/alist-web/releases/latest/download/dist.tar.gz'
```

例如：

```sh
ABCD_ADMIN_PASSWORD='你的强密码' bash <(curl -Ls https://raw.githubusercontent.com/tamd258/serv00-play/main/start.sh) --install-abcd
```


## 隐私说明

安装器不会内置、下载或写入任何网盘账号、cookie、token、存储配置或数据库。

如果你在同一个 serv00 账号上重装，旧的 `~/abcd/data` 里可能已经有你之前添加过的存储。默认安装会把旧数据备份到 `~/abcd/data.backup.时间戳` 并创建全新空数据目录；如果你确实想保留旧数据，请设置：

```sh
ABCD_KEEP_DATA=1 bash <(curl -Ls https://raw.githubusercontent.com/tamd258/serv00-play/main/start.sh) --install-abcd
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
