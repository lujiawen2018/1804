#!/bin/bash
#本地邮件
lab smtp-nullclient setup
#配置IPV4和IPV6
nmcli connection modify 'System eth0' ipv4.method manual ipv4.addresses '172.25.0.10/24 172.25.0.254' ipv4.dns 172.25.254.254 connection.autoconnect yes
nmcli connection modify 'System eth0' ipv6.method manual ipv6.addresses "2003:ac18::306/64" connection.autoconnect yes
nmcli connection up 'System eth0'
#修改主机名
hostnamectl set-hostname desktop0.example.com
#配置SSH访问
echo "DenyUsers *@*.my133t.org *@172.34.0.*" >> /etc/ssh/sshd_config
systemctl restart sshd
systemctl enable sshd
#自定义用户环境
echo "alias qstat='/bin/ps -Ao pid,tt,user,fname,rsz'" >> /etc/bashrc
#配置防火墙
firewall-cmd --set-default-zone=trusted
firewall-cmd --permanent --zone=block --add-source=172.34.0.0/24
#聚合链路
nmcli connection add type team con-name team0 ifname team0 config '{"runner":{"name":"activebackup"}}'
nmcli connection add type team-slave ifname eth1 master team0
nmcli connection add type team-slave ifname eth2 master team0
nmcli connection modify team0 ipv4.method manual ipv4.addresses 172.16.3.25/24 connection.autoconnect yes
nmcli connection up team0
nmcli connection up team-slave-eth1
nmcli connection up team-slave-eth2
#配置多用户Samba挂载
yum -y install samba-client cifs-utils
mkdir /mnt/dev
echo "//172.25.0.11/devops /mnt/dev cifs user=kenji,password=atenorth,multiuser,sec=ntlmssp,_netdev 0 0" >> /etc/fstab
mount -a
#挂载NFS共享
lab nfskrb5 setup
mkdir -p /mnt/nfsmount /mnt/nfssecure
wget -O /etc/krb5.keytab http://classroom/pub/keytabs/desktop0.keytab
systemctl restart nfs-secure
systemctl enable nfs-secure
echo "172.25.0.11:/public /mnt/nfsmount nfs _netdev 0 0
172.25.0.11:/protected /mnt/nfssecure nfs sec=krb5p,_netdev 0 0" >> /etc/fstab
mount -a
#配置ISCSI客户端
yum -y install iscsi-initiator-utils.i686
mkdir /mnt/data
echo "InitiatorName=iqn.2016-02.com.example:desktop0" > /etc/iscsi/initiatorname.iscsi
systemctl daemon-reload
systemctl restart iscsi iscsid
systemctl enable iscsi iscsid
iscsiadm --mode discoverydb --type sendtargets --portal 172.25.0.11 --discover
systemctl restart iscsi
yum -y install expect
expect << LJW
spawn fdisk /dev/sda
expect "m" {send "n\r"}
expect "default p" {send "\r"}
expect "分区号" {send "\r"}
expect "起始 扇区" {send "\r"}
expect "Last" {send "+2100M\r"}
expect "m" {send "w\r"}
expect ljw
LJW
mkfs.ext4 /dev/sda1
echo "$(blkid | awk '/sda/ {print $2}') /mnt/data ext4 _netdev 0 0" >> /etc/fstab
mount -a
sed -i 's/manual/automatic/g' /var/lib/iscsi/nodes/iqn.2016-02.com.example\:server0/172.25.0.11\,3260\,1/default
systemctl restart iscsi iscsid

