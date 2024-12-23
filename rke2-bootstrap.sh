#!/bin/bash

# Collect number of nodes and details as before
read -p "How many total nodes would you like to have in this cluster? " num_nodes

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

# Confirm input
echo "You have entered the following details:"
echo "  Server Node: $server_node (SSH Key: $server_ssh_key)"
for ip in "${!nodes[@]}"; do
    echo "  Node IP: $ip (SSH Key: ${nodes[$ip]})"
done

read -p "Do you want to proceed? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Exiting script."
    exit 0
fi

# Token to be used in the config.yaml
read -p "Enter the token to use for the RKE2 setup: " TOKEN

# Iterate over nodes and run commands
for ip in "${!nodes[@]}"; do
    ssh_key="${nodes[$ip]}"

    #if the node is the server node, use this block and omit the server field.
    if [[ "$ip" == "$server_node" ]]; then
        
        #create the config locally
        echo "token: $TOKEN
tls-san: " > server_config.yaml

        #copy the config to the remote machine
        scp -i "$ssh_key" server_config.yaml dgroh@"$ip":/tmp/config.yaml

        echo "Configuring server node ($ip)..."

        ssh -i "$ssh_key" dgroh@"$ip" <<'OUTER_EOF'
        TOKEN="$TOKEN"

        echo "Running commands on the server node..."

        # Download RKE2 binary
        curl -sfL https://get.rke2.io | sudo INSTALL_RKE2_VERSION=v1.30.8+rke2r1 sh -

        # Create RKE2 config directory and file
        sudo mkdir -p /etc/rancher/rke2

        # Move and rename the config
        sudo mv /tmp/config.yaml /etc/rancher/rke2/config.yaml

        # Enable and start RKE2 server
        sudo systemctl enable rke2-server.service
        sudo systemctl start rke2-server.service
OUTER_EOF

    #if the node is NOT the server node, use this block and add the server field.
    else

        echo "server: https://$server_node:9345
token: $TOKEN
tls-san: " > config.yaml

        #copy the config to the remote machine
        scp -i "$ssh_key" config.yaml dgroh@"$ip":/tmp/config.yaml

        echo "Configuring worker node ($ip)..."

        ssh -i "$ssh_key" dgroh@"$ip" <<'OUTER_EOF'
        TOKEN="$TOKEN"
        SERVER="$server_node"

        echo "Running commands on the additional server node..."

        # Download RKE2 binary
        curl -sfL https://get.rke2.io | sudo INSTALL_RKE2_VERSION=v1.30.8+rke2r1 sh -

        # Create RKE2 config directory and file
        sudo mkdir -p /etc/rancher/rke2

        # Move and rename the config
        sudo mv /tmp/config.yaml /etc/rancher/rke2/config.yaml

        # Enable and start RKE2 server
        sudo systemctl enable rke2-server.service
        sudo systemctl start rke2-server.service
OUTER_EOF
    fi
done


echo "Configuration complete!"
