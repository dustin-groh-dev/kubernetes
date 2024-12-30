#!/bin/bash


RKE2_VERSION="v1.30.8+rke2r1"


# Collect number of nodes and details as before
read -p "How many TOTAL nodes would you like to have in this cluster? " num_nodes

if ! [[ "$num_nodes" =~ ^[0-9]+$ ]]; then
    echo "Please enter a valid number."
    exit 1
fi

declare -A nodes
for (( i = 1; i <= num_nodes; i++ )); do
    if [[ i -eq 1 ]]; then
        echo "Enter details for node $i, this will be the first server node:"
    else
        echo "Enter details for node $i:"
    fi

    read -p "  IP Address: " ip_address
    read -p "  SSH Key Path (default: ~/.ssh/id_rsa): " ssh_key
    ssh_key=${ssh_key:-~/.ssh/id_rsa}

    if [[ ! -f "$ssh_key" ]]; then
        echo "  Warning: SSH key file $ssh_key not found. Please ensure this path is correct."
    fi

    if [[ $i -eq 1 ]]; then
        server_node="$ip_address"
        server_ssh_key="$ssh_key"
    fi

    nodes["$ip_address"]="$ssh_key"
done


# Collect rke2 version
read -p "What user would you like to use on the remote nodes? " node_user


# Confirm input
echo "You have entered the following details:"
echo "  Server Node: $server_node (SSH Key: $server_ssh_key)"
for ip in "${!nodes[@]}"; do
    echo "  Node IP: $ip (SSH Key: ${nodes[$ip]})"
done
echo " User: $node_user"

read -p "Do you want to proceed? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Exiting script."
    exit 0
fi

# Token to be used in the config.yaml
read -p "Enter the token to use for the RKE2 setup: " TOKEN

# Iterate over nodes and run commands
for ip in "${!nodes[@]}"; do

    #Do this for every node
    ssh_key="${nodes[$ip]}"
        
    #create the config locally
    echo "token: $TOKEN
tls-san: " > server_config.yaml

    # if the node being connected to is not the server node, ad the server field to the config.
    if [[ "$ip" != "$server_node" ]]; then
        echo "server: https://$server_node:9345" >> server_config.yaml
    fi

    #copy the config to the remo te machine
    scp -i "$ssh_key" server_config.yaml "$node_user"@"$ip":/tmp/config.yaml
        
    #ssh to host using IP entered above
    ssh -i "$ssh_key" "$node_user"@"$ip" <<OUTER_EOF

    echo "Running commands on the node..."

    # Download RKE2 binary
    curl -sfL https://get.rke2.io | sudo INSTALL_RKE2_VERSION=$RKE2_VERSION sh -

    # Create RKE2 config directory and file
    sudo mkdir -p /etc/rancher/rke2

    # Move and rename the config
    sudo mv /tmp/config.yaml /etc/rancher/rke2/config.yaml

    # Enable and start RKE2 server
    sudo systemctl enable rke2-server.service
    sudo systemctl start rke2-server.service

OUTER_EOF

    # remove config after it's been moved to remote machine
    rm -f server_config.yaml

# exit the for loop
done

echo " "
echo "Configuration complete!"
echo " "

echo "Setting kubeconfig to the new cluster. "
echo "kubeconfig will be placed at ~/.kube/config.yaml  "
echo " "

# output the kubeconfig from the server node and create a new file on the local machine as the kubeconfig
ssh -i "$ssh_key" "$node_user"@"$server_node" "sudo cat /etc/rancher/rke2/rke2.yaml" > "/tmp/kube_config.yaml"

# replace 127.0.0.1 with the IP of the server node in the kubeconfig.
sed -i "s/127.0.0.1/$server_node/g" /tmp/kube_config.yaml

# move to default location for kube config
mv /tmp/kube_config.yaml ~/.kube/config.yaml

# set kubeconfig context
export KUBECONFIG=~/.kube/config.yaml

echo "Running test kubectl command... "
echo " "

# test kubectl command
kubectl get nodes
