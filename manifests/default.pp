node 'localhost.lan', 'localhost', 'stage', 'production', 'ci', 'lepton.co' {
    include repo
    include java
    include ant
    include prayerlabs
}

if versioncmp($::puppetversion,'3.6.1') >= 0 {

  $allow_virtual_packages = hiera('allow_virtual_packages',false)

  Package {
    allow_virtual => $allow_virtual_packages,
  }
}
