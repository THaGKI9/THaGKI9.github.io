---
title: SSL Handshake 被莫名其妙地 RST
toc: true
date: 2019-05-09T21:42:09+0800
categories: 踩坑记录
thumbnail: /2019/05/09/wired-ssl-handshake-reset/wireshark-result-1.png
tags:
    - 踩坑
    - Nginx
    - SSL
---
最近我接的外包项目甲方又要开一个新的项目，于是丢过来几台阿里云的服务器，我来负责服务器基础架构的搭建，其实也就是网关，Runtime，Redis, Syslog 那些东西，已经做得滚瓜烂熟了。这次打算自己编译 OpenResty，调教出一个高性能网关，于是弄好了 OpenResty，也顺手把甲方发过来的 SSL 证书配置到了 OpenResty 上。

配置 HTTPS 的过程跟以前一样，设置好 `ssl_certificate`, `ssl_certificate_key`,`listen 443 ssl http2` 这些东西，再附加一些 `ssl_cipher` 方面的参数，`openresty -s reload` 完事。

`reload` 完了之后我在我本地的 Chrome 上通过域名访问了 `https://xxx.com` (xxx.com) 为甲方域名，一开始几次访问是 `ERROR_CONNECTION_RESET`，我也不以为然，因为服务器上的 OpenResty 刚 Reload，以及我本机上常着的 Surge 代理有时候可能会断线，所以我以为这种情况比较常见，刷新几次就好了，见到了 `Welcome To OpenResty`。

晚上回家之后团队的小伙伴告诉我他访问不了这个服务器的 https，我自己试了一下确实没法访问，一直提示 `ERROR_CONNECTION_RESET`，偶尔成功。这时候我才开始重视起来，准备研究一下这个问题。
<!-- more -->



### 症状
1. 在本机上 `curl` 只有极小的概率会返回正确结果，大部分时候返回
    ```shell
    $ curl https://xxx.com
    curl: (35) LibreSSL SSL_connect: SSL_ERROR_SYSCALL in connection to xxx.com:443
    ```
2. 在阿里云同一 VPC 内其他机器 `curl` 则必成功
3. 无论在哪里直接 `curl -k https://<ip>` 都是可以正常访问的

### 排查问题过程
1. 之前用的 SSL 证书都是使用 [`certbot`](https://certbot.eff.org/) 来自助签发 [`Let's Encrypt`](https://letsencrypt.org/) 的三个月证书，这次使用的是在阿里云买的 `Encryption Everywhere DV TLS CA - G1` 签发的证书，我猜测甲方发给我的证书格式有问题，但是很快否定了这个猜测，因为前面讲到刷新多几次还是能访问的，并且 Chrome 能够给出正确的证书信息。

2. 之前没有用过自己编译的 OpenResty，于是我换了个预编译版的 nginx，也就是直接通过 `yum install nginx` 来安装的 nginx，问题依旧。

3. 开了 `wireshark` 来抓包

   ![Failed Request](./wireshark-result-1.png)
   可以发现这么一个过程：`TCP Handshake -> SSL Client Hello -> Reset(Server sent) `

   我有幸地抓到了部分没有被 Reset 的请求，

   ![Successful Request](./wireshark-result-2.png)

   可以看出，成功的请求的 `Client Hello `与被 Reset 的 `Client Hello` 的大小都是 `583 Byte`，并且我详细的对比了两个 `Packet`，发现除了时间戳以及必要的随机数之外并没有不一样的地方。

   我查看一下了 OpenResty 的错误日志，发现有大量的 `peer closed connection in SSL handshake`：

   ```
   2019/05/09 22:23:48 [info] 5182#0: *5543 peer closed connection in SSL handshake (104: Connection reset by peer) while SSL handshaking, client: <ip>, server: 0.0.0.0:443
   2019/05/09 22:23:49 [info] 5183#0: *5544 peer closed connection in SSL handshake (104: Connection reset by peer) while SSL handshaking, client: <ip>, server: 0.0.0.0:443
   2019/05/09 22:23:49 [info] 5183#0: *5545 peer closed connection in SSL handshake (104: Connection reset by peer) while SSL handshaking, client: <ip>, server: 0.0.0.0:443
   2019/05/09 22:23:50 [info] 5183#0: *5546 peer closed connection in SSL handshake (104: Connection reset by peer) while SSL handshaking, client: <ip>, server: 0.0.0.0:443
   2019/05/09 22:23:50 [info] 5182#0: *5547 peer closed connection in SSL handshake (104: Connection reset by peer) while SSL handshaking, client: <ip>, server: 0.0.0.0:443
   2019/05/09 22:23:50 [info] 5183#0: *5548 peer closed connection in SSL handshake (104: Connection reset by peer) while SSL handshaking, client: <ip>, server: 0.0.0.0:443
   ```

   也就是说，OpenResty 认为客户端在握手过程中主动关闭了连接，但是我的抓包结果却是服务端主动 RST 了连接，这让我感到很疑惑，为何两端能得出不一样的结论。
   由于不是很理解 SSL 握手的机制，我猜测 `OpenSSL` 接管了这一过程，所以我重新编译了 OpenResty，加上了最新版的 OpenSSL，问题依旧。

4. 至此我没辙了，只能 Google, StackOverflow 一遍一遍地搜，搜到了用直接 OpenSSL 来建立 SSL 连接的方法，于是我

   ```shell
   $ openssl s_client -connect xxx.com:443
   CONNECTED(00000005)
   depth=2 C = US, O = DigiCert Inc, OU = www.digicert.com, CN = DigiCert Global Root CA
   verify return:1
   depth=1 C = US, O = DigiCert Inc, OU = www.digicert.com, CN = Encryption Everywhere DV TLS CA - G1
   verify return:1
   depth=0 CN = <Hidden Part>
   verify return:1
   ---
   Certificate chain
    0 s:/CN=e.duchenggo.com
      i:/C=US/O=DigiCert Inc/OU=www.digicert.com/CN=Encryption Everywhere DV TLS CA - G1
    1 s:/C=US/O=DigiCert Inc/OU=www.digicert.com/CN=Encryption Everywhere DV TLS CA - G1
      i:/C=US/O=DigiCert Inc/OU=www.digicert.com/CN=DigiCert Global Root CA
   ---
   Server certificate
   <Hidden Part>
   subject=/CN=<Hidden Part>
   issuer=/C=US/O=DigiCert Inc/OU=www.digicert.com/CN=Encryption Everywhere DV TLS CA - G1
   ---
   No client certificate CA names sent
   Server Temp Key: ECDH, X25519, 253 bits
   ---
   SSL handshake has read 3246 bytes and written 285 bytes
   ---
   New, TLSv1/SSLv3, Cipher is ECDHE-RSA-CHACHA20-POLY1305
   Server public key is 2048 bit
   Secure Renegotiation IS supported
   Compression: NONE
   Expansion: NONE
   No ALPN negotiated
   SSL-Session:
       Protocol  : TLSv1.2
       Cipher    : ECDHE-RSA-CHACHA20-POLY1305
       Session-ID: E5BC4CB0FFCA949F99859E6F2B6AE6D8742C6F6723EF7388ED7AED4F81C01126
       Session-ID-ctx:
       Master-Key: 86D3EB1512786A84CE6E0ACF43362174345399F7C32A89B725893D2791AF87EBD1F642600CCA9919D57CDCB6FF6B203B
       TLS session ticket lifetime hint: 300 (seconds)
       TLS session ticket:
       0000 - 85 3a da c6 e3 ab 66 f9-7b f8 e7 cd f6 a5 da e9   .:....f.{.......
       0010 - ba bc d9 15 74 cf 8d b0-56 ea 4d c9 b4 f3 b7 d1   ....t...V.M.....
       0020 - 1f 47 c1 1e ac 56 13 16-ca 6c d0 b8 bd 28 15 ea   .G...V...l...(..
       0030 - 59 b3 79 84 b0 40 34 a4-57 e9 d1 12 c2 b5 5e 0f   Y.y..@4.W.....^.
       0040 - 77 02 ff 8b 4c 23 2b 89-b6 25 61 15 af 77 7c 75   w...L#+..%a..w|u
       0050 - 6c 1f 80 66 27 0b 90 c4-36 43 e0 ee 75 f9 2d 99   l..f'...6C..u.-.
       0060 - a0 af d3 bf 6d 12 05 f9-13 21 46 fd 41 a8 56 da   ....m....!F.A.V.
       0070 - df ec 89 68 d1 71 9d 15-2e 2f fa de 89 6a a0 8e   ...h.q.../...j..
       0080 - 82 45 85 ca 3b 26 a0 e8-64 a9 56 82 da cf 04 4d   .E..;&..d.V....M
       0090 - 42 13 dc 25 17 aa 38 1e-36 0a 8f 66 b5 26 57 2c   B..%..8.6..f.&W,
       00a0 - 70 5e ff 0b 41 eb 49 f1-b0 8b 86 fd e6 c1 36 28   p^..A.I.......6(

       Start Time: 1557413139
       Timeout   : 7200 (sec)
       Verify return code: 0 (ok)
   ---
   ```

   成功建立了 SSL 连接，显示的证书也是正确的，并且每一次执行都能稳定建立连接，而不是看运气才能连接得上，我抓包了这个建立过程，发现这种 `Client Hello` 是不携带 [SNI Extension](<https://en.wikipedia.org/wiki/Server_Name_Indication>) 的，如果我手动给他附上 SNI 呢？

   ```shell
   $ openssl s_client xxx.com:443 -servername xxx.com
   CONNECTED(00000005)
   write:errno=54
   ---
   no peer certificate available
   ---
   No client certificate CA names sent
   ---
   SSL handshake has read 0 bytes and written 0 bytes
   ---
   New, (NONE), Cipher is (NONE)
   Secure Renegotiation IS NOT supported
   Compression: NONE
   Expansion: NONE
   No ALPN negotiated
   SSL-Session:
       Protocol  : TLSv1.2
       Cipher    : 0000
       Session-ID:
       Session-ID-ctx:
       Master-Key:
       Start Time: 1557413484
       Timeout   : 7200 (sec)
       Verify return code: 0 (ok)
   ---
   ```

   果不其然，无法完成握手！



### 锁定元凶

经过一系列排查之后，终于发现携带了 SNI 的 SSL 握手请求大概率会被 "神秘力量" Reset。

联想到这个域名还没有来得及备案，我猜想大概就是因为没有备案所以被干扰。但是以前的未备案只是 HTTP 会被劫持流量，难道阿里云已经增强了技术开始干扰未备案域名的 HTTPS 连接了吗？

搜索了一番发现很早之前就有人讨论过这个问题了

* [v2ex - 阿里云竟然也能 RESET 掉 HTTPS 链接了..?](https://www.v2ex.com/t/120181)
* [v2ex - 阿里云香港和新加坡 HTTPS 极其不稳定](https://www.v2ex.com/t/456423)

至此结束调查，请甲方去对域名进行备案。


-----
真是一个无聊的调查结果，不过也是记录一下，希望其他人遇到这个问题的时候能够搜到我的文章别再浪费时间到这个问题上
