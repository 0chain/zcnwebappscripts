sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod a+x /usr/local/bin/yq
yq e -i '.0box.public_key = "381fb2e8298680fc9c71e664821394adaa5db4537456aaa257ef4388ba8c090e476c89fbcd2c8a1b0871ba36b7001f778d178c8dfff1504fbafb43f7ee3b3c92"' /var/0chain/blobber/config/0chain_blobber.yaml
docker restart blobber_blobber_1
