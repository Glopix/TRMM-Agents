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

if [[ $DISPLAY ]]; then
    echo "ERROR: Display detected. Installer only supports running headless, i.e from ssh."
    echo "If you cannot ssh in then please run 'sudo systemctl isolate multi-user.target' to switch to a non-graphical user session and run the installer again."
    echo "If you are already running headless, then you are probably running with X forwarding which is setting DISPLAY, if so then simply run"
    echo "unset DISPLAY"
    echo "to unset the variable and then try running the installer again"
    exit 1
fi

DEBUG=0
INSECURE=0
NOMESH=0

# BEGIN UNOFFICIAL MODIFICATIONS
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

#agentDL='agentDLChange'
#meshDL='meshDLChange'

#apiURL='apiURLChange'
#token='tokenChange'

#
# END UNOFFICIAL MODIFICATIONS
# Official Script from here on (as of 2024-03-02)
#


clientID='clientIDChange'
siteID='siteIDChange'
agentType='agentTypeChange'
proxy=''

agentBinPath='/usr/local/bin'
binName='tacticalagent'
agentBin="${agentBinPath}/${binName}"
agentConf='/etc/tacticalagent'
agentSvcName='tacticalagent.service'
agentSysD="/etc/systemd/system/${agentSvcName}"
agentDir='/opt/tacticalagent'
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
    localedef -c -i en_US -f UTF-8 en_US.UTF-8 >/dev/null 2>&1
    localectl set-locale LANG=en_US.UTF-8
    . /etc/locale.conf
}

RemoveOldAgent() {
    if [ -f "${agentSysD}" ]; then
        systemctl disable ${agentSvcName}
        systemctl stop ${agentSvcName}
        rm -f "${agentSysD}"
        systemctl daemon-reload
    fi

    if [ -f "${agentConf}" ]; then
        rm -f "${agentConf}"
    fi

    if [ -f "${agentBin}" ]; then
        rm -f "${agentBin}"
    fi

    if [ -d "${agentDir}" ]; then
        rm -rf "${agentDir}"
    fi
}

InstallMesh() {
    if [ -f /etc/os-release ]; then
        distroID=$(
            . /etc/os-release
            echo $ID
        )
        distroIDLIKE=$(
            . /etc/os-release
            echo $ID_LIKE
        )
        if [[ " ${deb[*]} " =~ " ${distroID} " ]]; then
            set_locale_deb
        elif [[ " ${deb[*]} " =~ " ${distroIDLIKE} " ]]; then
            set_locale_deb
        elif [[ " ${rhe[*]} " =~ " ${distroID} " ]]; then
            set_locale_rhel
        else
            set_locale_rhel
        fi
    fi

    meshTmpDir='/root/meshtemp'
    mkdir -p $meshTmpDir

    meshTmpBin="${meshTmpDir}/meshagent"
    wget --no-check-certificate -q -O ${meshTmpBin} ${meshDL}
    chmod +x ${meshTmpBin}
    mkdir -p ${meshDir}
    env LC_ALL=en_US.UTF-8 LANGUAGE=en_US XAUTHORITY=foo DISPLAY=bar ${meshTmpBin} -install --installPath=${meshDir}
    sleep 1
    rm -rf ${meshTmpDir}
}

RemoveMesh() {
    if [ -f "${meshSystemBin}" ]; then
        env XAUTHORITY=foo DISPLAY=bar ${meshSystemBin} -uninstall
        sleep 1
    fi

    if [ -f "${meshSysD}" ]; then
        systemctl stop ${meshSvcName} >/dev/null 2>&1
        systemctl disable ${meshSvcName} >/dev/null 2>&1
        rm -f ${meshSysD}
    fi

    rm -rf ${meshDir}
    systemctl daemon-reload
}

Uninstall() {
    RemoveMesh
    RemoveOldAgent
}

if [ $# -ne 0 ] && [[ $1 =~ ^(uninstall|-uninstall|--uninstall)$ ]]; then
    Uninstall
    # Remove the current script
    rm "$0"
    exit 0
fi

while [[ "$#" -gt 0 ]]; do
    case $1 in
    -debug | --debug | debug) DEBUG=1 ;;
    -insecure | --insecure | insecure) INSECURE=1 ;;
    -nomesh | --nomesh | nomesh) NOMESH=1 ;;
    *)
        echo "ERROR: Unknown parameter: $1"
        exit 1
        ;;
    esac
    shift
done

RemoveOldAgent

echo "Downloading tactical agent..."
wget -q -O ${agentBin} "${agentDL}"
if [ $? -ne 0 ]; then
    echo "ERROR: Unable to download tactical agent"
    exit 1
fi
chmod +x ${agentBin}

MESH_NODE_ID=""

if [[ $NOMESH -eq 1 ]]; then
    echo "Skipping mesh install"
else
    if [ -f "${meshSystemBin}" ]; then
        RemoveMesh
    fi
    echo "Downloading and installing mesh agent..."
    InstallMesh
    sleep 2
    echo "Getting mesh node id..."
    MESH_NODE_ID=$(env XAUTHORITY=foo DISPLAY=bar ${agentBin} -m nixmeshnodeid)
fi

if [ ! -d "${agentBinPath}" ]; then
    echo "Creating ${agentBinPath}"
    mkdir -p ${agentBinPath}
fi

INSTALL_CMD="${agentBin} -m install -api ${apiURL} -client-id ${clientID} -site-id ${siteID} -agent-type ${agentType} -auth ${token}"

if [ "${MESH_NODE_ID}" != '' ]; then
    INSTALL_CMD+=" --meshnodeid ${MESH_NODE_ID}"
fi

if [[ $DEBUG -eq 1 ]]; then
    INSTALL_CMD+=" --log debug"
fi

if [[ $INSECURE -eq 1 ]]; then
    INSTALL_CMD+=" --insecure"
fi

if [ "${proxy}" != '' ]; then
    INSTALL_CMD+=" --proxy ${proxy}"
fi

eval ${INSTALL_CMD}

tacticalsvc="$(
    cat <<EOF
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
echo "${tacticalsvc}" | tee ${agentSysD} >/dev/null

systemctl daemon-reload
systemctl enable ${agentSvcName}
systemctl start ${agentSvcName}
