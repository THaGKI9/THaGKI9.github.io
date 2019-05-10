---
title: 由 Eval 引申到 Redis Cluster 的学习
toc: true
date: 2019-04-18T00:21:51Z
categories: 学习
tags:
    - redis
    - study
---

### 背景
因为业务需要写了一段 Redis 的 Lua Script，在调用 `EVAL` 的时候发现还有两个参数 `KEYS` 和 `ARGV`，感觉很疑惑，难道不是简单的传点参数进去就可以？所以了解了一下这两个参数的含义。

[EVAL](https://redis.io/commands/eval) 命令的定义是
```
EVAL script numkeys key [key ...] arg [arg ...]
```

> All Redis commands must be analyzed before execution to determine which keys the command will operate on. In order for this to be true for EVAL, keys must be passed explicitly. This is useful in many ways, but especially to make sure Redis Cluster can forward your request to the appropriate cluster node.

Redis 设计的原意是使用者应当将在 Lua Script 中操作的所有 KEY 以 KEYS 的形式传给 EVAL，这样 EVAL 能够在真正运行前检查一下 KEY，就目前来说，是根据 KEYS 来决定把指令转发到哪台 Redis Cluster Master Node 上。
ARGV 则是传递一些必要的参数，这个倒是没什么使用规范。

于是我先放下 EVAL，了解一下 Redis Cluster，用了这么久 Redis 了，还没用过 Redis Cluster，惭愧。
<!-- more -->

### Redis Cluster
Redis Cluster 简单的来说就是若干 Redis 节点组成集群，数据根据 KEY 被分散到不同的节点上面，而不是节点之间互为 Replication。KEY 的分散策略不是 Consistent Hashing，而是一种叫做 **Slots** 的机制，在文章最后我再介绍一下我对 Slots 机制的理解。
也正是因为 Slots 机制，指令到达 Redis Cluster 的节点之后会根据 KEY 选择合适的 Slot，然后客户端重新连接到对应的节点再执行操作，而不是某个节点转发指令到对应 KEY 的节点。
一个 Redis Cluster 一共有 16384 个 Slots，最开始创建集群的时候这 16384 个 Slots 会被平均分散到各个节点上面，也可以通过命令来手动调整，至于为什么是 16384 个 Slots，感兴趣的同学可以看一下作者在这个 [Issue](https://github.com/antirez/redis/issues/2576) 上的回答

### Availability
前面说到 Redis 节点之间数据互相独立，所以只要有节点挂了，这个节点负责的 Slots 的数据也变得无法访问从而整个集群的节点都会拒绝访问，处于 `CLUSTERDOWN` 的状态。
因此 Redis Cluster 也利用了 Master-Slave 机制用于提供 Availability，即 Master 节点会异步复制自己的数据（其实是复制操作）到它 N 个的 Slave 节点，也就是说一个 Slot 对应的 Key 们会有 N+1 份数据分布在 Master 和 Slave 上。
当某个 Master 挂了的时候，集群会把它的 Slave 升级到 Master，这样子集群就能继续工作。当然，如果一对 Master-Slave 都挂了那集群也就挂了。
通常来说，所有操作都会在 Master 上进行，Slave 只是充当备胎的作用，只有 Master 挂了 Slave 才能上位。不过 Slave 也不是一无是处，客户端可以通过执行 `READONLY` 命令来将客户端切换到只读模式，这样子读操作就会在 Slave 上进行。

### Consistency
Redis Cluster 并不能保证很好的数据一致性，在某些极端情况下还是有可能丢数据的：

#### 第一种丢失数据的情况
Master 没有成功复制消息到 Slave。在 Master-Slave 模式下，对 Master 的操作是同步的，即操作成功后才会返回给客户端相应的消息，但是 Master -> Slave 的复制是异步的，假设一种情况：
1. 客户端 SET a 1
2. Master 接收到指令 SET a 1，回复给客户端 OK
3. Master 在发送给 Slave SET a 1 之前崩了
4. Slave 上位成 Master
这时候 a=1 这个数据就丢失了。
这种情况也不是不能避免，Redis Cluster 提供了 WAIT 指令来做到这件事情。客户端发送 WAIT 指令之后，Redis Cluster 会 Block 住直到客户端的上一条操作有 N 个 Slave 都回复 ACK 了。

#### 第二种丢失数据的情况

网络隔离。假设我们有一个三节点集群，每个 Master 节点有一个 Slave，节点命名为 A-A1, B-B1, C-C1，以及一个客户端 D
发生网络隔离的情况下，D 和少数 Master（C） 形成一个孤岛，其他大多数 Master 形成一个孤岛。

|      | 孤岛 A<br>D、C | 孤岛 B<br> A、A1、B、B1、C1 |
|:----:|:-------------:|:-------------------------:|
|  t0  | C 与集群失联，开始等待恢复连接<br>等待时间为 `node timeout`<sup>[4]</sup> | 集群与 B 失联，开始等待 B 恢复连接<br>等待时间为 `node timeout` |
|  t1  | D 向 C 节点写数据 | 持续等待 |
|  t2  | C 等待超时<br>切换状态到 error，拒绝写入新数据 | 集群等待超时<br>通过选举将 C1 提升为新的 Master |
|  t3  | 与集群恢复联系 | 与 D C 恢复联系 |

恢复联系后，因为原来的 Master C 已经被多数成员认为不可用淘汰掉了，C1 被选为新的 Master，C 加回集群后被降级为 Slave。
因为先前 D 向 C 写的数据没有同步到 C1，所以数据丢失。

### 回到 EVAL
在一个节点接收到 EVAL 指令之后，他会检查 KEYS，算出对应的 Slots，如果所有 KEY 不是落到同一个 Slot 上，会提示 `CROSSSLOT Keys in request don't hash to the same slot`

那如果我不传 KEYS，直接在脚本中操作呢？还是会报错。
```
$ redis-cli EVAL "redis.call('get', 'slot a'); redis.call('get', 'slot-b')" 0
ERR Error running script (call to f_8ead0f68893988e15c455c0b6c8ab9982e2e707c): @user_script:1: @user_script: 1: Lua script attempted to access a non local key in a cluster node
```

所以 EVAL 的时候，脚本中操作的 Key 应当**保证落在同一个 Slot 里面**。同时 Redis 也提供了一个方法可以保证 Key 都会落到同一个 Slot 上面，下面讲 Slots 机制的时候会讲到
以上关于 EVAL 的操作都是建立在对 Redis Cluster 操作的基础上的，如果使用的是单一节点，则可以不考虑这些问题，可以胡来。
> Note this rule is not enforced in order to provide the user with opportunities to abuse the Redis single instance configuration, at the cost of writing scripts not compatible with Redis Cluster.

### Slots 机制
> SLOT = CRC16(key) mod 16384

Redis 集群的拓扑结构是是一个全连通的网络，每一个节点之间都会建立一个 Cluster Bus，所以集群的任何配置变动都会立即同步到各个节点，也就是说，每一个节点都知道哪些 Slot 对应哪个节点。
所以不论客户端连接到哪个节点进行执行指令，服务端都会正确的指示客户端应当重定向到哪一个节点来操作。
Key 在做 CRC16 的时候，如果 Key 中存在花括号对，Redis 会使用花括号对里面字符串做 CRC16，例如

```
{user:info:}1234 => crc16("user:info:") % 16384
{user:info:}5737 => crc16("user:info:") % 16384
```
虽然是两个不同的 Key，但是花括号中间部分是一样的，所以他们有相同的 Slot。

### 参考资料
* [1] https://github.com/antirez/redis/issues/2576
* [2] https://redis.io/topics/cluster-spec
* [3] https://redis.io/commands/eval
* [4] https://redis.io/topics/cluster-tutorial