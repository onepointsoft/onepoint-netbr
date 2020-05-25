#!/bin/bash
systemctl start mariadb
systemctl start vault
for a in `mysql -u root vault -sN -e "select AES_DECRYPT(pwd,'set') from token where id_utente like 'token%';" | awk -F ' ' '{print $1}'`
do
export VAULT_ADDR=http://127.0.0.1:8200
/opt/vault/bin/vault operator unseal $a
done
