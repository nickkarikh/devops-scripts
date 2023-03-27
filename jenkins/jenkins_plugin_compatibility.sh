#!/bin/bash

# This script outputs list of installed uncompatible (with JENKINS_VERSION) plugins and suggests compatible versions if any
# Please change 3 values below

JENKINS_HOME=/var/lib/jenkins
JENKINS_VERSION=2.345
PLUGIN_EXT=hpi

vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 0
        fi
    done
    return 0
}

processPlugin() {
    PLUGIN_NAME=$1
    PLUGIN_MIN_JENKINS_VERSION=$( unzip -p "${JENKINS_HOME}/plugins/${PLUGIN_NAME}.${PLUGIN_EXT}" META-INF/MANIFEST.MF | tr -d '\r' | sed -e ':a;N;$!ba;s/\n //g' | grep -e "^Jenkins-Version: " | awk '{ print $2 }' )
    if vercomp "${PLUGIN_MIN_JENKINS_VERSION}" "${JENKINS_VERSION}"; then
        :
    else
        echo -n "${PLUGIN_NAME}... "
        echo -n "Not OK. Detecting latest compatible version..."
        repo_res=$(curl -s https://updates.jenkins.io/download/plugins/${PLUGIN_NAME}/)
        re='<li id="([^"]+)"><a[^>]+>[^<]+</a><div[^>]+>\s*<div[^>]+>[^<]+</div>\s*<div[^>]+>[^<]+<code>[^<]+</code></div>\s*<div[^>]+>[^<]+<code>[^<]+</code></div>\s*<div[^>]+>Requires Jenkins ([0-9.]+)</div>' #  .+?Requires Jenkins ([0-9.]+).+?</li>'
        PLUGIN_VERSION_FOUND=false
        while [[ "$repo_res" =~ $re ]]; do
            PLUGIN_VERSION=${BASH_REMATCH[1]}
            PLUGIN_MIN_JENKINS_VERSION=${BASH_REMATCH[2]}
            if vercomp "${PLUGIN_MIN_JENKINS_VERSION}" "${JENKINS_VERSION}"; then
                echo " ${PLUGIN_VERSION}"
                PLUGIN_VERSION_FOUND=true
                break
            fi
            repo_res=${repo_res/"${BASH_REMATCH[0]}"/}
        done
        if [ "$PLUGIN_VERSION_FOUND" = false ] ; then
            echo " NO COMPATIBLE VERSION FOUND!"
        fi
#        exit 0
    fi
}

for f in ${JENKINS_HOME}/plugins/*.${PLUGIN_EXT} ; do
    processPlugin $(basename ${f} .${PLUGIN_EXT})
done
