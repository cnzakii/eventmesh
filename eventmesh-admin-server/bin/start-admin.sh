#!/bin/bash
#
# Licensed to Apache Software Foundation (ASF) under one or more contributor
# license agreements. See the NOTICE file distributed with
# this work for additional information regarding copyright
# ownership. Apache Software Foundation (ASF) licenses this file to you under
# the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

#===========================================================================================
# Java Environment Setting
#===========================================================================================
set -e
# Server configuration may be inconsistent, add these configurations to avoid garbled code problems
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

TMP_JAVA_HOME="/customize/your/java/home/here"

# Detect operating system.
OS=$(uname)

function is_java8_or_11 {
        local _java="$1"
        [[ -x "$_java" ]] || return 1
        [[ "$("$_java" -version 2>&1)" =~ 'java version "1.8' || "$("$_java" -version 2>&1)" =~ 'openjdk version "1.8' || "$("$_java" -version 2>&1)" =~ 'java version "11' || "$("$_java" -version 2>&1)" =~ 'openjdk version "11' ]] || return 2
        return 0
}

function extract_java_version {
    local _java="$1"
    local version=$("$_java" -version 2>&1 | awk -F '"' '/version/ {print $2}' | awk -F '.' '{if ($1 == 1 && $2 == 8) print "8"; else if ($1 == 11) print "11"; else print "unknown"}')
    echo "$version"
}

# 0(not running),  1(is running)
#function is_proxyRunning {
#        local _pid="$1"
#        local pid=`ps ax | grep -i 'org.apache.eventmesh.runtime.boot.EventMeshStartup' |grep java | grep -v grep | awk '{print $1}'|grep $_pid`
#        if [ -z "$pid" ] ; then
#            return 0
#        else
#            return 1
#        fi
#}

function get_pid {
        local ppid=""
        if [ -f ${EVENTMESH_ADMIN_HOME}/bin/pid-admin.file ]; then
                ppid=$(cat ${EVENTMESH_ADMIN_HOME}/bin/pid-admin.file)
                # If the process does not exist, it indicates that the previous process terminated abnormally.
    if [ ! -d /proc/$ppid ]; then
      # Remove the residual file.
      rm ${EVENTMESH_ADMIN_HOME}/bin/pid-admin.file
      echo -e "ERROR\t EventMesh process had already terminated unexpectedly before, please check log output."
      ppid=""
    fi
        else
                if [[ $OS =~ Msys ]]; then
                        # There is a Bug on Msys that may not be able to kill the identified process
                        ppid=`jps -v | grep -i "org.apache.eventmesh.admin.server.ExampleAdminServer" | grep java | grep -v grep | awk -F ' ' {'print $1'}`
                elif [[ $OS =~ Darwin ]]; then
                        # Known problem: grep Java may not be able to accurately identify Java processes
                        ppid=$(/bin/ps -o user,pid,command | grep "java" | grep -i "org.apache.eventmesh.admin.server.ExampleAdminServer" | grep -Ev "^root" |awk -F ' ' {'print $2'})
                else
                  if [ $DOCKER ]; then
                    # No need to exclude root user in Docker containers.
                    ppid=$(ps -C java -o user,pid,command --cols 99999 | grep -w $EVENTMESH_ADMIN_HOME | grep -i "org.apache.eventmesh.admin.server.ExampleAdminServer" | awk -F ' ' {'print $2'})
                  else
        # It is required to identify the process as accurately as possible on Linux.
        ppid=$(ps -C java -o user,pid,command --cols 99999 | grep -w $EVENTMESH_ADMIN_HOME | grep -i "org.apache.eventmesh.admin.server.ExampleAdminServer" | grep -Ev "^root" | awk -F ' ' {'print $2'})
      fi
                fi
        fi
        echo "$ppid";
}

#===========================================================================================
# Locate Java Executable
#===========================================================================================

if [[ -d "$TMP_JAVA_HOME" ]] && is_java8_or_11 "$TMP_JAVA_HOME/bin/java"; then
        JAVA="$TMP_JAVA_HOME/bin/java"
        JAVA_VERSION=$(extract_java_version "$TMP_JAVA_HOME/bin/java")
elif [[ -d "$JAVA_HOME" ]] && is_java8_or_11 "$JAVA_HOME/bin/java"; then
        JAVA="$JAVA_HOME/bin/java"
        JAVA_VERSION=$(extract_java_version "$JAVA_HOME/bin/java")
elif is_java8_or_11 "$(which java)"; then
        JAVA="$(which java)"
        JAVA_VERSION=$(extract_java_version "$(which java)")
else
        echo -e "ERROR\t Java 8 or 11 not found, operation abort."
        exit 9;
fi

echo "EventMesh using Java version: $JAVA_VERSION, path: $JAVA"

EVENTMESH_ADMIN_HOME=$(cd "$(dirname "$0")/.." && pwd)
export EVENTMESH_ADMIN_HOME

EVENTMESH_ADMIN_LOG_HOME="${EVENTMESH_ADMIN_HOME}/logs"
export EVENTMESH_ADMIN_LOG_HOME

echo -e "EVENTMESH_ADMIN_HOME : ${EVENTMESH_ADMIN_HOME}\nEVENTMESH_ADMIN_LOG_HOME : ${EVENTMESH_ADMIN_LOG_HOME}"

function make_logs_dir {
        if [ ! -e "${EVENTMESH_ADMIN_LOG_HOME}" ]; then mkdir -p "${EVENTMESH_ADMIN_LOG_HOME}"; fi
}

error_exit ()
{
    echo -e "ERROR\t $1 !!"
    exit 1
}

export JAVA_HOME

#===========================================================================================
# JVM Configuration
#===========================================================================================
#if [ $1 = "prd" -o $1 = "benchmark" ]; then JAVA_OPT="${JAVA_OPT} -server -Xms2048M -Xmx4096M -Xmn2048m -XX:SurvivorRatio=4"
#elif [ $1 = "sit" ]; then JAVA_OPT="${JAVA_OPT} -server -Xms256M -Xmx512M -Xmn256m -XX:SurvivorRatio=4"
#elif [ $1 = "dev" ]; then JAVA_OPT="${JAVA_OPT} -server -Xms128M -Xmx256M -Xmn128m -XX:SurvivorRatio=4"
#fi

GC_LOG_FILE="${EVENTMESH_ADMIN_LOG_HOME}/eventmesh_admin_gc_%p.log"

JAVA_OPT="${JAVA_OPT} -server -Xms1g -Xmx1g"
JAVA_OPT="${JAVA_OPT} -XX:+UseG1GC -XX:G1HeapRegionSize=16m -XX:G1ReservePercent=25 -XX:InitiatingHeapOccupancyPercent=30 -XX:SoftRefLRUPolicyMSPerMB=0 -XX:SurvivorRatio=8 -XX:MaxGCPauseMillis=50"
JAVA_OPT="${JAVA_OPT} -verbose:gc"
if [[ "$JAVA_VERSION" == "8" ]]; then
    # Set JAVA_OPT for Java 8
    JAVA_OPT="${JAVA_OPT} -Xloggc:${GC_LOG_FILE} -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=5 -XX:GCLogFileSize=30m"
    JAVA_OPT="${JAVA_OPT} -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCApplicationStoppedTime -XX:+PrintAdaptiveSizePolicy"
elif [[ "$JAVA_VERSION" == "11" ]]; then
    # Set JAVA_OPT for Java 11
    XLOG_PARAM="time,level,tags:filecount=5,filesize=30m"
    JAVA_OPT="${JAVA_OPT} -Xlog:gc*:${GC_LOG_FILE}:${XLOG_PARAM}"
    JAVA_OPT="${JAVA_OPT} -Xlog:safepoint:${GC_LOG_FILE}:${XLOG_PARAM} -Xlog:ergo*=debug:${GC_LOG_FILE}:${XLOG_PARAM}"
fi
JAVA_OPT="${JAVA_OPT} -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=${EVENTMESH_ADMIN_LOG_HOME} -XX:ErrorFile=${EVENTMESH_ADMIN_LOG_HOME}/hs_err_%p.log"
JAVA_OPT="${JAVA_OPT} -XX:-OmitStackTraceInFastThrow"
JAVA_OPT="${JAVA_OPT} -XX:+AlwaysPreTouch"
JAVA_OPT="${JAVA_OPT} -XX:MaxDirectMemorySize=8G"
JAVA_OPT="${JAVA_OPT} -XX:-UseLargePages -XX:-UseBiasedLocking"
JAVA_OPT="${JAVA_OPT} -Dio.netty.leakDetectionLevel=advanced"
JAVA_OPT="${JAVA_OPT} -Dio.netty.allocator.type=pooled"
JAVA_OPT="${JAVA_OPT} -Djava.security.egd=file:/dev/./urandom"
JAVA_OPT="${JAVA_OPT} -Dlog4j.configurationFile=${EVENTMESH_ADMIN_HOME}/conf/log4j2.xml"
JAVA_OPT="${JAVA_OPT} -Deventmesh.log.home=${EVENTMESH_ADMIN_LOG_HOME}"
JAVA_OPT="${JAVA_OPT} -DconfPath=${EVENTMESH_ADMIN_HOME}/conf"
JAVA_OPT="${JAVA_OPT} -DconfigurationPath=${EVENTMESH_ADMIN_HOME}/conf"
JAVA_OPT="${JAVA_OPT} -Dlog4j2.AsyncQueueFullPolicy=Discard"
JAVA_OPT="${JAVA_OPT} -Drocketmq.client.logUseSlf4j=true"
JAVA_OPT="${JAVA_OPT} -DeventMeshPluginDir=${EVENTMESH_ADMIN_HOME}/plugin"

#if [ -f "pid.file" ]; then
#        pid=`cat pid.file`
#        if ! is_proxyRunning "$pid"; then
#            echo "proxy is running already"
#            exit 9;
#        else
#           echo "err pid$pid, rm pid.file"
#            rm pid.file
#        fi
#fi

pid=$(get_pid)
if [[ $pid == "ERROR"* ]]; then
  echo -e "${pid}"
  exit 9
fi
if [ -n "$pid" ]; then
        echo -e "ERROR\t The server is already running (pid=$pid), there is no need to execute start.sh again."
        exit 9
fi

make_logs_dir

echo "Using Java version: $JAVA_VERSION, path: $JAVA" >> ${EVENTMESH_ADMIN_LOG_HOME}/eventmesh-admin.out

EVENTMESH_ADMIN_MAIN=org.apache.eventmesh.admin.server.ExampleAdminServer
if [ $DOCKER ]; then
        $JAVA $JAVA_OPT -classpath ${EVENTMESH_ADMIN_HOME}/conf:${EVENTMESH_ADMIN_HOME}/apps/*:${EVENTMESH_ADMIN_HOME}/lib/* $EVENTMESH_ADMIN_MAIN >> ${EVENTMESH_ADMIN_LOG_HOME}/eventmesh-admin.out
else
        $JAVA $JAVA_OPT -classpath ${EVENTMESH_ADMIN_HOME}/conf:${EVENTMESH_ADMIN_HOME}/apps/*:${EVENTMESH_ADMIN_HOME}/lib/* $EVENTMESH_ADMIN_MAIN >> ${EVENTMESH_ADMIN_LOG_HOME}/eventmesh-admin.out 2>&1 &
echo $!>${EVENTMESH_ADMIN_HOME}/bin/pid-admin.file
fi
exit 0
