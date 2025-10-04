# cloud-init-builder
Build cloud-init.yamls from multiple files

# usage
 1. create a cloud-init.tmpl.yaml containing `#include: <relative-base-dir> lines`
    e.g.
    ```yaml
    #cloud-config
    fqdn: host.example.com
    
    write_files:
      #include: write_files/ << THIS IS KEY
    apt:
      sources:
        salt.sources:
          source: "deb https://packages.broadcom.com/artifactory/saltproject-deb stable main"
          key: |
            -----BEGIN PGP PUBLIC KEY BLOCK-----
            -----END PGP PUBLIC KEY BLOCK-----
    
    package_update: true
    package_upgrade: true
    package_reboot_if_required: true
    
    packages:
      - salt-minion
    
    runcmd:
      - salt-call --local state.apply
    ```
 3. ```sh
    go run main.go <directory where cloud-init.tmpl.yaml lives>
    ```
    or
    ```sh
    main.go <directory where cloud-init.tmpl.yaml lives>
    ```
    if you built the Go file or downloaded the release

    1. the program goes through all files until the bottom of the specified directory
    2. for each file, it will inlcude the content, keeping the indentation of the comment
    3. send the expanded file to stdout
 4. pipe or send the output to an editor or file
