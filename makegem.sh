#!/bin/sh -x

gem build vagrant-google.gemspec
vagrant plugin install ./vagrant-google-0.1.0.gem

if [ ! -L ~/.vagrant.d/gems/gems/fog-1.12.1 ]; then
  echo "WARNING: you are likely not running Nat's latest fog branch"
  echo "  git clone https://github.com/icco/fog"
  echo "  cd fog"
  echo "  git checkout next_version"
  echo "  gem build fog.gemspec"
  echo "  gem install fog-1.12.1.gem  # => takes a while..."
  echo "  cd ~/.vagrant.d/gems/gems"
  echo "  mv fog-1.12.1 fog-1.12.1.bak"
  echo "  ln -s /var/lib/gems/1.9.1/gems/fog-1.12.1"
fi
