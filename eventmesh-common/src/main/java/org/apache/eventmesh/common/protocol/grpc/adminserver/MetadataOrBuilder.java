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

package org.apache.eventmesh.common.protocol.grpc.adminserver;// Generated by the protocol buffer compiler.  DO NOT EDIT!
// source: event_mesh_admin_service.proto

public interface MetadataOrBuilder extends
    // @@protoc_insertion_point(interface_extends:Metadata)
    com.google.protobuf.MessageOrBuilder {

    /**
     * <code>string type = 3;</code>
     *
     * @return The type.
     */
    String getType();

    /**
     * <code>string type = 3;</code>
     *
     * @return The bytes for type.
     */
    com.google.protobuf.ByteString
    getTypeBytes();

    /**
     * <code>map&lt;string, string&gt; headers = 7;</code>
     */
    int getHeadersCount();

    /**
     * <code>map&lt;string, string&gt; headers = 7;</code>
     */
    boolean containsHeaders(
        String key);

    /**
     * Use {@link #getHeadersMap()} instead.
     */
    @Deprecated
    java.util.Map<String, String>
    getHeaders();

    /**
     * <code>map&lt;string, string&gt; headers = 7;</code>
     */
    java.util.Map<String, String>
    getHeadersMap();

    /**
     * <code>map&lt;string, string&gt; headers = 7;</code>
     */

    String getHeadersOrDefault(
        String key,
        String defaultValue);

    /**
     * <code>map&lt;string, string&gt; headers = 7;</code>
     */

    String getHeadersOrThrow(
        String key);
}
