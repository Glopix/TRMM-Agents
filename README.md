# TacticalRMM-Agent for Linux
Checks [amidaware/rmmagent](https://github.com/amidaware/rmmagent) every 2 days and builds new agent binaries for Linux if there was an update.  
See [Releases](https://github.com/Glopix/TRMM-Agents/releases/)  

## Installation
To install the agent on linux you can use:  
### A) Offical installation script:  
https://github.com/amidaware/tacticalrmm/blob/develop/api/tacticalrmm/core/agent_linux.sh  
  
### or  
### B) this modified installation script:  
https://github.com/Glopix/TRMM-Agents/blob/main/rmmAgent_install.sh  
It is based on the offical installation script but with some changes, e.g. the download links for the agent binaries from this repo are already included.  
  
```
wget https://raw.githubusercontent.com/Glopix/TRMM-Agents/main/rmmAgent_install.sh
chmod +x rmmAgent_install.sh
```
