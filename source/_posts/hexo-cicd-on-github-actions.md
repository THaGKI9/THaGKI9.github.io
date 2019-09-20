---
title: 使用 GitHub Actions 完成自动化部署 Hexo 博客
toc: true
date: 2019-09-20T23:33:36+0800
categories: ShareAnything
thumbnail: /2019/09/20/hexo-cicd-on-github-actions/preview.png
tags:
    - GitHub Actions
    - 建站之路
    - CI
    - Hexo
    - 踩坑
---

GitHub 于 2018 年 8 月向公众宣告了他们的 CI 系统 [GitHub Actions](<https://github.blog/2018-10-17-action-demos/>)，这是一套自动化的工作流系统，可以对一个项目的开发起到很好的辅助作用。

直到我写这篇文章的时候，GitHub Actions 还处于 Beta 阶段。我已经拿到了测试资格，出于尝鲜的目的，便把我的博客的自动化部署从 Travis 转移到 Actions 上。

写此文章分享我对 GitHub Actions 的了解。由于我之前只用过 Travis 和 Jenkins，而 Jenkins 的使用作为一个非运维人员来说是不太需要关心的，所以下文介绍 Actions 的过程中，我更多地会通过对比 Travis 来进行介绍。

<!-- more -->

<br>

## 简单介绍 GitHub Actions

市面上比较流行的同类产品有：

- Travis，是一个第三方在线 CI/CD 服务提供商，一开始向 GitHub 的仓库提供免费服务，后来遍逐渐地成为了多数 GitHub 用户的首选

- AppVeyor，与 Travis 不同的是，AppVeyor 提供了比较好的 Windows 环境支持，这吸引了一部分 Windows 软件开发者
- Jenkins，这是一套开源的 CI/CD 系统，很多商业公司会选择在内部服务器自己搭建一套完整的 CI/CD 系统，并与他们的私有库以及线上机器集群结合起来，从而优化工作流。我的前东家们（字节跳动、即刻）使用的都是这样子的结构



<br>

### 一些概念

#### Workflow

一个 Workflow 即是一个可配置的自动化工作流，这个工作流由单个或者多个 *Job* 组成。工作流的启动可以通过事件（比如 git push）来触发，也可以通过定时任务来触发。

Workflow 的配置通过一个 yaml 文档来体现，这个文档存放在 `<repo>/.github/workflows/<workflow_name>.yml`，具体规范可见 [Workflow syntax for GitHub Actions](<https://help.github.com/en/articles/workflow-syntax-for-github-actions>)，本文不会提及所有语法内容，只会覆盖需要用到的语句。

#### Job

由一系列具体 *Step* 组成的一个任务。每一个 Job 会运行在一个独立的虚拟环境里面。Job 之间可以是并行的，也可以是有依赖关系的，这个可以在 Workflow 中进行配置。

举个🌰，一个项目可以由四个 Job 组成：

* 两个编译基础组件的 Job（并行）
* 一个编译主程序的 Job（依赖上面两个 Job）
* 一个运行测试用例的 Job（当且仅当主程序 Job 编译成功的时候运行）

#### Step

Step 定义了每一个步骤所做的事情，可以是运行某行命令，或者是使用某一个 *Action*。Step 的运行与否是可以通过条件来控制的，但本文不会 Cover 这个内容。

#### Action

一个 Workflow 可以抽象成为一个比较通用的功能，从而分享给别人使用。Action 就是这样的存在。

在 GitHub Actions 里面，是不会像 Travis 那样默认从当前 Repo 去 Clone 源码的，你需要定义一个 Step 来 Checkout。当然，每次写 Workflow 都要写上 `git clone blablabla` 无疑是对人力的一种不必要损耗，于是就有了一个叫做 [checkout](<https://github.com/actions/checkout>) 的 Action。

<br>

## 使用 Action 部署 Hexo

先贴上我的 Workflow 定义 [deploy.yml](<https://github.com/THaGKI9/THaGKI9.github.io/blob/source/.github/workflows/deploy.yml>)，然后我们逐行解析这份 Workflow 定义

```yml
name: Compile and Deploy to GitHub Page

on:
  push:
    branches:
      - source

jobs:
  build:
    runs-on: ubuntu-18.04
    steps:
    - uses: actions/checkout@v1
      with:
        submodules: true
        ref: refs/heads/source

    - uses: actions/setup-node@v1
      with:
        node_version: '8.x'

    - name: Setup Git user info
      run: |
        git config --global user.email "thagki9@outlook.com"
        git config --global user.name "GitHub Actions"

    - name: Install dependencies
      run: npm ci

    - name: Compile and deploy blog
      run: ./deploy.sh
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

<br>

### Workflow 的名称

```yml
# line 1
name: Compile and Deploy to GitHub Page
```

定义这个 Workflow 的名称为「Compile and Deploy to GitHub Page」

### 触发条件

```yml
# line 3-6
on:
  push:
    branches:
      - source
```

定义了在事件  `push` 发生，并且目标分支为 `source ` 的时候触发这个 Workflow

### Jobs

```yml
# line 8-10
jobs:
  build:
    runs-on: ubuntu-18.04
    steps:
    - ...
    - ...
    - ...
    - ...
    - ...
```

在这个简单的项目里面，我只有一个叫做 `build` 的 Job，基础运行环境是 `ubuntu-18.04`，目前[可以选择的基础环境](<https://help.github.com/en/articles/workflow-syntax-for-github-actions#jobsjob_idruns-on>)有 `ubuntu`, `windows` 和 `macOS`。这个 Job 包含了 5 个小任务

### 步骤 1、2、3：设置基础环境

````yml
# line 12-24
		- uses: actions/checkout@v1
      with:
        submodules: true
        ref: refs/heads/source

    - uses: actions/setup-node@v1
      with:
        node_version: '8.x'

    - name: Setup Git user info
      run: |
        git config --global user.email "thagki9@outlook.com"
        git config --global user.name "GitHub Actions"
````

第一个步骤使用了 `actions/checkout` 的预定义 Action，携带了参数 `submodules` 和 `ref`，表示将会从默认目录（跟环境变量有关）Clone 分支 `source`，并且 Clone 相应的 `submodule`。

第二个步骤使用了 `actions/setup-node` ，携带参数 `node_version`，表示将会设置好 node 8.x 的环境。

第三个步骤我给他定义了个名字叫做「Setup Git user info」，运行了两行命令，用于设置 git 命令行的默认邮箱和名称。

关于参数的使用，涉及到一个叫做 *Context* 的概念，不过在上面概念介绍的时候我没有提及，有兴趣的读者可以阅读 [Contexts and expression syntax for GitHub Actions](<https://help.github.com/en/articles/contexts-and-expression-syntax-for-github-actions>)。

### 步骤 4：安装项目依赖

```yml
# line 26-27
    - name: Install dependencies
      run: npm ci
```

这个步骤只执行了一行命令，那就是 `npm ci`，用于安装项目的第三方依赖，包括 Hexo 等等。

### 步骤 5：执行部署脚本

```yml
# line 29-32
    - name: Compile and deploy blog
      run: ./deploy.sh
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

这里比较有意思的是执行脚本的时候附带了一个 `GITHUB_TOKEN` 的环境变量，这个变量的内容是 `${{ secrets.GITHUB_TOKEN }}` ，这是一种 Actions Workflow 提供的语法，用于使用一些灵活的表达式，比如这个表达式的意思就是从 `secrets` 这个 Context 拿 `GITHUB_TOKEN` 这个值。

`secrets.GITHUB_TOKEN` 其实是 GitHub Actions 预定义的一个值，这个值就是一个 OAuth Access Token，可以用来对 GitHub 库进行读写操作。显然我们不愿意在 Workflow 里面写上自己的 GitHub 账户和密码，所以这里我们会用到 Access Token 来 Push 最终的博客静态文件到 GitHub Page 库。并且由于 GitHub Actions 有对敏感数据的保护，所以 `secrets` 下的所有变量是不会泄露到日志里面的。

`deploy.sh` 的内容我就不解析了，大概就是 Clone 了原有的 GitHub Pages 仓库，删掉里面的所有东西，然后重新生成，以产生正确的 Diff 记录，最后 Commit & Push。

<br>

## GitHub Actions 的机会

那么，作为一款新入市场的产品，Actions 凭什么能和其他成熟产品竞争呢？

在我看来有几个关键点

* 与 GitHub 的无缝融合是天生优势，在 Actions 能用的情况下，谁又会去使用第三方的 CI/CD 呢
* Workflow 的可复用性在 GitHub 这个开源社区显得更为耀眼，减少了很多重复工作，其实上面这些部署步骤，我相信我去搜索一下「GitHub Actions Workflow Deploy Hexo」，直接 `uses` 一下应该也是 OK 的
* 微软的慷慨：每个 Repo 可以同时运行 20 个 Workflow；每个 Job 可以运行长达 6 个小时；高性能的运行环境。这无疑是对开源社区的一种馈赠，开源软件的 CI/CD 可以更高效地推进
* 功能的强大：在仔细阅读了文档之后我发现 Actions 提供的功能是非常强大的，轻量 Workflow 配置也赋予了 Actions 更多的可能。如果在正式商用之后能够给出比较合适的价格，我相信有些小型企业是会乐意使用 GitHub + GitHub Actions 的模式来进行开发的





