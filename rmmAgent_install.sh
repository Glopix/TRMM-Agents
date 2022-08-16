#!/usr/bin/env bash

if [ $EUID -ne 0 ]; then
  echo "ERROR: Must be run as root"
  exit 1
fi

HAS_SYSTEMD=$(ps --no-headers -o comm 1)
if [ "${HAS_SYSTEMD}" != 'systemd' ]; then
    echo "This install script only supports systemd"
    echo "Please install systemd or manually create the service using your systems's service manager"
    exit 1
fi

# Tactical RMM Agent from
# https://github.com/Glopix/TRMM-Agents/releases

# Linux ARM64 (ARMv8)
# env CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -ldflags "-s -w"
agentDL_ARM64='https://github.com/Glopix/TRMM-Agents/releases/download/latest/rmmAgent_linux_arm64.go'

# Linux ARM32 (ARMv7)
# env CGO_ENABLED=0 GOOS=linux GOARCH=arm32 GOARM=7 go build -ldflags "-s -w"
agentDL_ARM32='https://github.com/Glopix/TRMM-Agents/releases/download/latest/rmmAgent_linux_arm32.go'

# Linux AMD64
# env CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags "-s -w"
agentDL_AMD64='https://github.com/Glopix/TRMM-Agents/releases/download/latest/rmmAgent_linux_amd64.go'


# get MeshCentral Agent URL (or edit it here)
MESHCENTRAL_URL=''

while [[ $MESHCENTRAL_URL != *[.]*[.]* ]]
do
	echo "enter the MeshCentral domain (e.g. mesh.example.com): "
	read MESHCENTRAL_URL 
done

#(machine)id from https://github.com/Ylianst/MeshCentral/blob/master/agents/meshinstall-linux.sh
# Linux arm64: id=26
meshDL_ARM64=$MESHCENTRAL_URL'/meshagents?id=26'

# Linux arm32: id=25
meshDL_ARM32=$MESHCENTRAL_URL'/meshagents?id=25'

# Linux x64: id=6
meshDL_AMD64=$MESHCENTRAL_URL'/meshagents?id=6'

# get API URL (or edit it here)
apiURL=''
while [[ $apiURL != *[.]*[.]* ]]
do
	echo "enter the API domain (e.g. api.example.com): "
	read apiURL 
done

# determine Architecture
ARCH="$(uname -m)"
case $ARCH in

  'armv7l' | 'armv7')
	agentDL=$agentDL_ARM32
	meshDL=$meshDL_ARM32
    ;;

  'armv8' | 'aarch64')
    agentDL=$agentDL_ARM64
	meshDL=$meshDL_ARM64
    ;;

  'x86_64' | 'amd64')
    agentDL=$agentDL_AMD64
	meshDL=$meshDL_AMD64
    ;;

  *)
    echo -n "unknown Architecture"
	exit 1
    ;;
	
esac	
	
# get Token (or edit it here)
token=''

REGEX='^(\w+\S+)$'
while [[ ! "$token" =~ $REGEX ]]
do
	echo "enter TacticalRMM token:"
	read token 
done

echo "TacticalRMM Agent download: " $agentDL
echo "Mesh download: " $meshDL
#
# MODIFICATION END
# Official Script from here on (as of 2022-08-08)
#

clientID='1'
siteID='1'
agentType='"server"'
proxy=''

agentBinPath='/usr/local/bin'
binName='tacticalagent'
agentBin="${agentBinPath}/${binName}"
agentConf='/etc/tacticalagent'
agentSvcName='tacticalagent.service'
agentSysD="/etc/systemd/system/${agentSvcName}"
meshDir='/opt/tacticalmesh'
meshSystemBin="${meshDir}/meshagent"
meshSvcName='meshagent.service'
meshSysD="/lib/systemd/system/${meshSvcName}"

deb=(ubuntu debian raspbian kali linuxmint)
rhe=(fedora rocky centos rhel amzn arch opensuse)

set_locale_deb() {
locale-gen "en_US.UTF-8"
localectl set-locale LANG=en_US.UTF-8
. /etc/default/locale
}

set_locale_rhel() {
localedef -c -i en_US -f UTF-8 en_US.UTF-8 > /dev/null 2>&1
localectl set-locale LANG=en_US.UTF-8
. /etc/locale.conf
}

RemoveOldAgent() {
    if [ -f "${agentSysD}" ]; then
        systemctl disable --now ${agentSvcName}
        rm -f ${agentSysD}
        systemctl daemon-reload
    fi

    if [ -f "${agentConf}" ]; then
        rm -f ${agentConf}
    fi

    if [ -f "${agentBin}" ]; then
        rm -f ${agentBin}
    fi
}

InstallMesh() {
    if [ -f /etc/os-release ]; then
        distroID=$(. /etc/os-release; echo $ID)
        if [[ " ${deb[*]} " =~ " ${distroID} " ]]; then
            set_locale_deb
        elif [[ " ${rhe[*]} " =~ " ${distroID} " ]]; then
            set_locale_rhel
        else
            set_locale_rhel
        fi
    fi

    meshTmpDir=$(mktemp -d -t "mesh-XXXXXXXXX")
    if [ $? -ne 0 ]; then
        meshTmpDir='meshtemp'
        mkdir -p ${meshTmpDir}
    fi
    meshTmpBin="${meshTmpDir}/meshagent"
    wget --no-check-certificate -q -O ${meshTmpBin} ${meshDL}
    chmod +x ${meshTmpBin}
    mkdir -p ${meshDir}
    env LC_ALL=en_US.UTF-8 LANGUAGE=en_US ${meshTmpBin} -install --installPath=${meshDir}
    sleep 1
    rm -rf ${meshTmpDir}
}

RemoveMesh() {
    if [ -f "${meshSystemBin}" ]; then
        ${meshSystemBin} -uninstall
        sleep 1
    fi

    if [ -f "${meshSysD}" ]; then
        systemctl disable --now ${meshSvcName} > /dev/null 2>&1
        rm -f ${meshSysD}
    fi

    rm -rf ${meshDir}
    systemctl daemon-reload
}

Uninstall() {
    RemoveMesh
    RemoveOldAgent
}

if [ $# -ne 0 ] && [ $1 == 'uninstall' ]; then
    Uninstall
    exit 0
fi


RemoveOldAgent

echo "Downloading tactical agent..."
wget --no-check-certificate -O ${agentBin} "${agentDL}"
chmod +x ${agentBin}

MESH_NODE_ID=""

if [ $# -ne 0 ] && [ $1 == '--nomesh' ]; then
    echo "Skipping mesh install"
else
    if [ -f "${meshSystemBin}" ]; then
        RemoveMesh
    fi
    echo "Downloading and installing mesh agent..."
    InstallMesh
    sleep 2
    echo "Getting mesh node id..."
    MESH_NODE_ID=$(${agentBin} -m nixmeshnodeid)
fi

if [ ! -d "${agentBinPath}" ]; then
    echo "Creating ${agentBinPath}"
    mkdir -p ${agentBinPath}
fi

if [ $# -ne 0 ] && [ $1 == '--debug' ]; then
    INSTALL_CMD="${agentBin} -m install -api ${apiURL} -client-id ${clientID} -site-id ${siteID} -agent-type ${agentType} -auth ${token} -log debug"
else
    INSTALL_CMD="${agentBin} -m install -api ${apiURL} -client-id ${clientID} -site-id ${siteID} -agent-type ${agentType} -auth ${token}"
fi

if [ "${MESH_NODE_ID}" != '' ]; then
    INSTALL_CMD+=" -meshnodeid ${MESH_NODE_ID}"
fi

if [ "${proxy}" != '' ]; then
    INSTALL_CMD+=" -proxy ${proxy}"
fi

eval ${INSTALL_CMD}

tacticalsvc="$(cat << EOF
[Unit]
Description=Tactical RMM Linux Agent

[Service]
Type=simple
ExecStart=${agentBin} -m svc
User=root
Group=root
Restart=always
RestartSec=5s
LimitNOFILE=1000000
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
)"
echo "${tacticalsvc}" | tee ${agentSysD} > /dev/null

systemctl daemon-reload
systemctl enable --now ${agentSvcName}
