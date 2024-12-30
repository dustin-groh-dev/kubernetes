## What this is 
This is a script to bootstrap an RKE2 cluster using existing nodes and SSH. <br>
If you've used the ```rke config``` option for RKE1 it's very similar in function.

## Prerequisites
The assumption of this script is that wherever you're running it from (a local machine, utility host, etc) has: 1. ssh keys 
set up for all the nodes you want to bootstrap 2. kubectl set up in your path. <br>

You'll also need root access to download and run the RKE2 installation script.

## How to Use

1. Download the script. <br>
2. Set your desired RKE2 version in the script variable **RKE2_VERSION**<br>
3. Run it ```. rke2_bootstrap.sh``` <br>
4. Input your IP addresses and SSH key paths in the terminal and let the script do it's thing.


Server node docs: <br>
https://docs.rke2.io/install/quickstart#server-node-installation <br>
https://docs.rke2.io/install/ha#2-launch-the-first-server-node
