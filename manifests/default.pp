node 'localhost.lan', 'localhost', 'stage', 'production', 'ci', 'rraise.co' {
    include repo
    include java
    include ant
    include rraise
}

if versioncmp($::puppetversion,'3.6.1') >= 0 {

  $allow_virtual_packages = hiera('allow_virtual_packages',false)

  Package {
    allow_virtual => $allow_virtual_packages,
  }
}
