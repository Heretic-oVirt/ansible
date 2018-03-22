# TODO list for Ansible files

The following TODO items are taken stright from Kickstart comments in heresiarch.ks (where the Ansible files were created initially) which were written outside of the relevant files.
Please note that further (specific) TODO lines still exist inside single YAML/Jinja2 files.

* either remove the password-related variables from global group var files or at least encrypt them with Ansible Vault

* encrypt with Ansible Vault in oVirt default vars file (maybe only the password-related part)

* remove roles/glusternodes/test_plugins/custom.py when the equalto test in Jinja2 selectattr will be supported (added in Jinja2 2.8)

* add NFS-Ganesha to roles/glusternodes/glustercleanup.yaml when ready

* add NFS-Ganesha to roles/glusternodes/storageservices.yaml when ready

* add support for VLAN eth (not only plain and bond) to roles/ovirtnodes/ovirtnodes.yaml

* in roles/ovirtnodes/templates/he-answers.j2: find a way to determine the local mgmt network address also when mgmt is not the main interface (eg default gateway on lan network)

* in roles/ovirtnodes/templates/he-answers.j2: find out why the for loop does not insert a newline at the end - added another one as a workaround

* in roles/ovirtnodes/templates/he-answers.j2: open RFE Bugzilla ticket and add cloudinit parameters for cluster and datacenter names when supported upstream

* in roles/ovirtengine/ovirtengine.yaml: find a way to determine the local mgmt network address also when mgmt is not the main interface (eg default gateway on lan network)

* add support for BMC options in roles/ovirtengine/ovirtengine.yaml

* in roles/glusternodes/templates/smb.j2: lower log level to 0 general and vfs-glusterfs too

* in roles/glusternodes/adjoin.yaml: add nfs principal and extract/propagate keytab for kerberized NFSv4 Ganesha operations when ready

* in roles/ovirtengine/ovirtvms.yaml: finish provisioning of vms (AD DC, printer server, DB server, application server, firewall/proxy and virtual desktops) from scratch (kickstart based installation - not from template)


