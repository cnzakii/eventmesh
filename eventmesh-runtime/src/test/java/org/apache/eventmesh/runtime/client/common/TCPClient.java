/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.apache.eventmesh.runtime.client.common;

import org.apache.eventmesh.common.EventMeshThreadFactory;
import org.apache.eventmesh.common.protocol.tcp.Package;

import java.io.Closeable;
import java.net.InetSocketAddress;
import java.util.Random;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ScheduledThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

import io.netty.bootstrap.Bootstrap;
import io.netty.buffer.PooledByteBufAllocator;
import io.netty.channel.AdaptiveRecvByteBufAllocator;
import io.netty.channel.Channel;
import io.netty.channel.ChannelDuplexHandler;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelFutureListener;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.ChannelInitializer;
import io.netty.channel.ChannelOption;
import io.netty.channel.SimpleChannelInboundHandler;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.socket.SocketChannel;
import io.netty.channel.socket.nio.NioSocketChannel;

import lombok.extern.slf4j.Slf4j;

/**
 * one Client connects one ACCESS Provides the most basic connection, send capability, and cannot provide disconnected reconnection capability, The
 * service is request-dependent. If the disconnection and reconnection capability is provided, it will cause business insensitivity, that is, it will
 * not follow the business reconnection logic.
 */
@Slf4j
public abstract class TCPClient implements Closeable {

    public int clientNo = (new Random()).nextInt(1000);

    protected ConcurrentHashMap<Object, RequestContext> contexts = new ConcurrentHashMap<>();

    protected String host = "127.0.0.1";

    protected int port = 10000;

    private final Bootstrap bootstrap = new Bootstrap();

    protected static final ScheduledThreadPoolExecutor scheduler = new ScheduledThreadPoolExecutor(4,
        new EventMeshThreadFactory("TCPClientScheduler", true));

    private final NioEventLoopGroup workers = new NioEventLoopGroup(8, new EventMeshThreadFactory("TCPClientWorker"));

    public Channel channel;

    protected boolean isActive() {
        return (channel != null) && (channel.isActive());
    }

    public TCPClient(String host, int port) {
        this.host = host;
        this.port = port;
    }

    protected void send(Package msg) throws Exception {
        if (channel.isWritable()) {
            channel.writeAndFlush(msg).addListener((ChannelFutureListener) future -> {
                if (!future.isSuccess()) {
                    log.warn("send msg failed: {}, {}", future.isSuccess(), future.cause());
                }
            });
        } else {
            channel.writeAndFlush(msg).sync();
        }
    }

    protected Package io(Package msg, long timeout) throws Exception {
        if (msg.getHeader().getSeq() == null) {
            send(msg);
            return null;
        } else {
            Object key = RequestContext.getHeaderSeq(msg);
            CountDownLatch latch = new CountDownLatch(1);
            RequestContext c = RequestContext.context(key, msg, latch);
            if (!contexts.contains(c)) {
                contexts.put(key, c);
            } else {
                log.info("duplicate key : {}", key);
            }
            send(msg);
            if (!c.getLatch().await(timeout, TimeUnit.MILLISECONDS)) {
                throw new TimeoutException("operation timeout, context.key=" + c.getKey());
            }

            return c.getResponse();
        }
    }

    protected synchronized void open(SimpleChannelInboundHandler<Package> handler) throws Exception {
        bootstrap.group(workers);
        bootstrap.channel(NioSocketChannel.class);
        bootstrap.option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 1_000)
            .option(ChannelOption.SO_KEEPALIVE, Boolean.FALSE)
            .option(ChannelOption.SO_SNDBUF, 64 * 1024)
            .option(ChannelOption.SO_RCVBUF, 64 * 1024)
            .option(ChannelOption.RCVBUF_ALLOCATOR, new AdaptiveRecvByteBufAllocator(1024, 8192, 65536))
            .option(ChannelOption.ALLOCATOR, PooledByteBufAllocator.DEFAULT);
        bootstrap.handler(new ChannelInitializer<SocketChannel>() {

            public void initChannel(SocketChannel ch) throws Exception {
                ch.pipeline().addLast(new Codec.Encoder(), new Codec.Decoder())
                    .addLast(handler, newExceptionHandler());
            }
        });

        ChannelFuture f = bootstrap.connect(host, port).sync();
        InetSocketAddress localAddress = (InetSocketAddress) f.channel().localAddress();
        channel = f.channel();
        log.info("connected|local={}:{}|server={}", localAddress.getAddress().getHostAddress(), localAddress.getPort(), host + ":" + port);
    }

    protected synchronized void reconnect() throws Exception {
        ChannelFuture f = bootstrap.connect(host, port).sync();
        channel = f.channel();
    }

    private ChannelDuplexHandler newExceptionHandler() {
        return new ChannelDuplexHandler() {

            @Override
            public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
                log.warn("exceptionCaught, close connection.|remote address={}", ctx.channel().remoteAddress(), cause);
                ctx.close();
            }
        };
    }

    @Override
    public synchronized void close() {
        try {
            channel.disconnect().sync();
        } catch (InterruptedException e) {
            log.warn("close tcp client failed.|remote address={}", channel.remoteAddress(), e);
        }
        workers.shutdownGracefully();
    }
}
