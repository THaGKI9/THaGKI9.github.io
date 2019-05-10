---
title: 在 macOS 上构建、打包 Medis
date: 2018-07-19 00:00:57
categories: 分享
toc: true
thumbnail: /2018/07/19/build-medis-on-macos/medis-gui-preview.png
tags:
    - DIY
    - Medis
---
[Medis](https://github.com/luin/medis) 是一款简洁易用、实用的 Redis 图形化客户端，作者将这款软件在 Github 上开源，所有开发者可以自由下载它的源代码。

Medis 在 App Store 上提供了下载，价值 ¥30，算是一种形式上的捐赠吧，不愿意花钱的开发者也可以根据本文的指示来构建并打包 Medis，与从 App Store下载的版本并无区别。
<!-- more -->

### 前提

- Xcode >= 8.2.1
- macOS >= 10.11.6
- Node 8（我只在装了 Node 8 的机器上尝试过）

### 自力更生

```shell
# 1. 下载最新源代码
$ git clone https://github.com/luin/medis.git
Cloning into 'medis'...
remote: Counting objects: 3154, done.
remote: Total 3154 (delta 0), reused 0 (delta 0), pack-reused 3154
Receiving objects: 100% (3154/3154), 48.44 MiB | 1.89 MiB/s, done.
Resolving deltas: 100% (1745/1745), done.
$ cd medis

# 2. 安装依赖
$ npm install
...
added 1295 packages from 1824 contributors in 49.707s

# 3. 打包，忽略 Unhandled rejection Error
$ npm run pack
Packaging app for platform mas x64 using electron v1.4.15
flating... ~/Desktop/medis/out/Medis-mas-x64/Medis.app
Unhandled rejection Error: No identity found for signing.
    at ~/Desktop/medis/node_modules/electron-osx-sign/flat.js:114:35
	...(stack error info)
```

至此，Medis 已经打包完毕，`Medis.app` 存放在 Medis 源代码目录下的 `out/Medis-mas-x64` 目录里面，运行 `Medis.app` 即可启动 Medis

### 安装

也可以在 `Finder` 中将 `Medis.app` 放入**应用程序**目录来安装，也可以用运行如下命令来安装：

```shell
# 此时处于 Medis 源代码根目录下
$ mv out/Medis-mas-x64/Medis.app ~/Applications
```

**Let's enjoy Medis!**

**Thank you [luin](https://github.com/luin)!**
